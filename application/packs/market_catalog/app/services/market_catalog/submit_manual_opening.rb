# frozen_string_literal: true

require "uri"

module MarketCatalog
  class SubmitManualOpening
    class InvalidInput < StandardError; end
    class ContractViolation < StandardError; end

    COMMAND_NAME = "job_opening.submit_manual"
    INGRESS_INTERFACE = "web/manual"

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
        SubmitOpening.call(
          workspace_id:,
          title:,
          company_name:,
          url:,
          location:,
          remote_policy:,
          compensation:,
          notes:,
          command: provenance.except(:message_id),
          ingress_interface: INGRESS_INTERFACE,
          reliability_api:
        )
      end.fetch(:result)
    rescue Platform::Reliability::Api::Error => error
      raise ContractViolation, "reliability boundary rejected manual opening submission: #{error.message}"
    rescue SubmitOpening::InvalidInput => error
      raise InvalidInput, error.message
    rescue SubmitOpening::ContractViolation => error
      raise ContractViolation, error.message
    end

    private

    attr_reader :workspace_id, :title, :company_name, :url, :location, :remote_policy,
      :compensation, :notes, :command, :reliability_api, :command_executor

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

    def optional_string(value)
      value.to_s.strip.presence
    end
  end
end
