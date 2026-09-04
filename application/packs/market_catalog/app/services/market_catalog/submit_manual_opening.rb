# frozen_string_literal: true

require "uri"

module MarketCatalog
  class SubmitManualOpening
    class InvalidInput < StandardError; end
    class ContractViolation < StandardError; end

    COMMAND_NAME = "job_opening.submit_manual"
    CREATED_EVENT = "job_opening.created"
    SUBMITTED_EVENT = "job_opening.manual_submission_recorded"
    AGGREGATE_TYPE = "JobOpening"
    RESOLVER_KEY = "manual_submission"
    RESOLVER_VERSION = "1"

    SOURCE_HOSTS = {
      "dou.ua" => "dou",
      "jobs.dou.ua" => "dou",
      "djinni.co" => "djinni",
      "work.ua" => "work_ua",
      "www.work.ua" => "work_ua",
      "robota.ua" => "robota_ua",
      "www.robota.ua" => "robota_ua",
      "remoteok.com" => "remoteok",
      "www.remoteok.com" => "remoteok",
      "linkedin.com" => "linkedin",
      "www.linkedin.com" => "linkedin",
      "indeed.com" => "indeed",
      "www.indeed.com" => "indeed"
    }.freeze

    class << self
      def call(
        workspace_id:,
        title:,
        command:,
        company_name: nil,
        url: nil,
        location: nil,
        remote_policy: nil,
        compensation: nil,
        notes: nil,
        reliability_api: Platform::Reliability::Api,
        command_executor: Platform::Reliability::CommandExecutor
      )
        new(
          workspace_id:,
          title:,
          company_name:,
          url:,
          location:,
          remote_policy:,
          compensation:,
          notes:,
          command:,
          reliability_api:,
          command_executor:
        ).call
      end
    end

    def initialize(
      workspace_id:,
      title:,
      company_name:,
      url:,
      location:,
      remote_policy:,
      compensation:,
      notes:,
      command:,
      reliability_api:,
      command_executor:
    )
      @workspace_id = workspace_id.to_s
      @title = title.to_s.strip.gsub(/\s+/, " ")
      @company_name = optional_string(company_name)
      @url = normalize_url(url)
      @location = optional_string(location)
      @remote_policy = optional_string(remote_policy)
      @compensation = optional_string(compensation)
      @notes = optional_string(notes)
      @command = command
      @reliability_api = reliability_api
      @command_executor = command_executor
    end

    def call
      validate_workspace!
      raise InvalidInput, "title is required" if title.blank?

      provenance = normalized_command
      payload = submission_payload

      reliability_api.receive_command(
        message_id: provenance.fetch(:message_id),
        command_id: provenance.fetch(:command_id),
        idempotency_key: provenance.fetch(:idempotency_key),
        command_name: COMMAND_NAME,
        interface: provenance.fetch(:interface),
        client: provenance.fetch(:client),
        principal: provenance.fetch(:principal),
        credential: provenance.fetch(:credential),
        actor: provenance.fetch(:actor),
        executor: provenance.fetch(:executor),
        correlation_id: provenance[:correlation_id],
        causation_id: provenance[:causation_id],
        payload:
      )

      command_executor.call(command_id: provenance.fetch(:command_id)) do
        persist_submission(provenance:)
      end.fetch(:result)
    rescue Platform::Reliability::Api::Error => error
      raise ContractViolation, "reliability boundary rejected manual opening submission: #{error.message}"
    rescue ActiveRecord::RecordInvalid, RecordPosting::IdentityConflict => error
      raise InvalidInput, error.message
    end

    private

    attr_reader :workspace_id, :title, :company_name, :url, :location, :remote_policy,
      :compensation, :notes, :command, :reliability_api, :command_executor

    def persist_submission(provenance:)
      now = Time.current
      company = find_or_create_company
      posting = url && record_posting(company:, observed_at: now)
      existing_opening = posting&.job_opening
      opening = existing_opening || CreateOpening.call(
        canonical_title: title,
        first_seen_at: now,
        primary_company_id: company&.id,
        metadata: opening_metadata
      )

      link_posting(posting:, opening:, decided_at: now) if posting && posting.job_opening_id.nil?
      append_event(
        opening:,
        posting:,
        event_type: existing_opening ? SUBMITTED_EVENT : CREATED_EVENT,
        occurred_at: now,
        provenance:
      )

      {
        opening_id: opening.typed_id,
        posting_id: posting&.typed_id,
        created: existing_opening.nil?
      }.compact.freeze
    end

    def find_or_create_company
      return if company_name.blank?

      normalized = company_name.downcase.gsub(/\s+/, " ")
      Company.find_by(normalized_name: normalized) || CreateCompany.call(
        canonical_name: company_name,
        metadata: {
          "first_ingress_interface" => "web/manual"
        }
      )
    end

    def record_posting(company:, observed_at:)
      RecordPosting.call(
        source_key: source_key,
        title:,
        observed_at:,
        canonical_url: url,
        publisher_company_id: company&.id,
        metadata: {
          "ingress_interface" => "web/manual",
          "source_host" => source_host,
          "submitted_by_workspace" => workspace_id
        }
      )
    end

    def link_posting(posting:, opening:, decided_at:)
      ResolvePostingOpeningLink.call(
        posting_id: posting.typed_id,
        opening_id: opening.typed_id,
        confidence: 1.0,
        evidence: [
          {
            "type" => "manual_submission",
            "url" => url,
            "ingress_interface" => "web/manual"
          }
        ],
        resolver_key: RESOLVER_KEY,
        resolver_version: RESOLVER_VERSION,
        decided_at:,
        metadata: { "workspace_id" => workspace_id }
      )
    end

    def opening_metadata
      {
        "ingress_interface" => "web/manual",
        "submitted_url" => url,
        "company_name" => company_name,
        "location_wording" => location,
        "remote_policy_wording" => remote_policy,
        "compensation_original_text" => compensation,
        "manual_notes" => notes
      }.compact
    end

    def submission_payload
      {
        workspace_id:,
        title:,
        company_name:,
        url:,
        location:,
        remote_policy:,
        compensation:,
        notes:
      }.compact
    end

    def append_event(opening:, posting:, event_type:, occurred_at:, provenance:)
      aggregate_id = opening.typed_id
      data = {
        "workspace_id" => workspace_id,
        "job_opening_id" => aggregate_id,
        "job_posting_id" => posting&.typed_id,
        "title" => opening.canonical_title,
        "company_name" => company_name,
        "submitted_url" => url,
        "ingress_interface" => "web/manual"
      }.compact

      reliability_api.append_domain_event(
        event_type:,
        event_version: 1,
        aggregate_type: AGGREGATE_TYPE,
        aggregate_id:,
        expected_aggregate_version: Platform::Reliability::AggregateVersion.call(
          aggregate_type: AGGREGATE_TYPE,
          aggregate_id:
        ),
        occurred_at:,
        effective_at: occurred_at,
        principal: provenance.fetch(:principal),
        credential: provenance.fetch(:credential),
        actor: provenance.fetch(:actor),
        executor: provenance.fetch(:executor),
        interface: provenance.fetch(:interface),
        client: provenance.fetch(:client),
        correlation_id: provenance[:correlation_id],
        causation_id: provenance[:causation_id],
        command_id: provenance.fetch(:command_id),
        idempotency_key: provenance.fetch(:idempotency_key),
        data:,
        outbox_messages: [
          {
            message_type: event_type,
            message_version: 1,
            payload: data,
            available_at: occurred_at
          }
        ]
      )
    end

    def normalized_command
      raise InvalidInput, "command must be an object" unless command.is_a?(Hash)

      attributes = command.to_h.symbolize_keys
      required = %i[idempotency_key principal credential actor executor interface client]
      missing = required.reject do |field|
        value = attributes[field]
        value.is_a?(String) && value.strip.present?
      end
      raise InvalidInput, "command provenance is incomplete: #{missing.join(', ')}" if missing.any?

      key = attributes.fetch(:idempotency_key).strip
      command_id = "#{COMMAND_NAME}:#{key}"
      {
        message_id: "#{command_id}:message",
        command_id:,
        idempotency_key: command_id,
        principal: attributes.fetch(:principal).strip,
        credential: attributes.fetch(:credential).strip,
        actor: attributes.fetch(:actor).strip,
        executor: attributes.fetch(:executor).strip,
        interface: attributes.fetch(:interface).strip,
        client: attributes.fetch(:client).strip,
        correlation_id: optional_string(attributes[:correlation_id]),
        causation_id: optional_string(attributes[:causation_id])
      }.freeze
    rescue KeyError => error
      raise InvalidInput, "missing command provenance field: #{error.key}"
    end

    def validate_workspace!
      typed_id = TypeID.from_string(workspace_id)
      raise InvalidInput, "workspace_id must be an org TypeID" unless typed_id.prefix == "org"

      current = ActiveRecord::Base.connection.select_value(
        "SELECT current_setting('app.current_organization', true)"
      )
      raise InvalidInput, "workspace database scope is required" if current.blank?
      raise InvalidInput, "workspace_id does not match the database scope" unless current == typed_id.uuid.to_s
    rescue TypeID::Error
      raise InvalidInput, "workspace_id must be an org TypeID"
    end

    def normalize_url(value)
      string = optional_string(value)
      return unless string

      uri = URI.parse(string)
      raise InvalidInput, "url must use http or https" unless %w[http https].include?(uri.scheme) && uri.host.present?

      uri.fragment = nil
      uri.to_s
    rescue URI::InvalidURIError
      raise InvalidInput, "url must be a valid http or https URL"
    end

    def source_host
      URI.parse(url).host.to_s.downcase
    end

    def source_key
      SOURCE_HOSTS.fetch(source_host, "web")
    end

    def optional_string(value)
      value.to_s.strip.presence
    end
  end
end
