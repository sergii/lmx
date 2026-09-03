# frozen_string_literal: true

require "digest"

module PersonalCrm
  module Api
    class Error < StandardError; end
    class InvalidInput < Error; end
    class NotFound < Error; end
    class ContractViolation < Error; end

    OPENING_SAVED = "personal_crm.opening.saved"
    OPENING_IGNORED = "personal_crm.opening.ignored"
    APPLICATION_STARTED = "personal_crm.application.started"
    AGGREGATE_TYPE = "personal_crm_opportunity"

    module_function

    def save_opening(workspace_id:, candidate_id:, job_opening_id:, command:,
      reliability_api: Platform::Reliability::Api,
      command_executor: Platform::Reliability::CommandExecutor)
      execute_disposition_command(
        workspace_id:,
        candidate_id:,
        job_opening_id:,
        state: "saved",
        event_type: OPENING_SAVED,
        command_name: "personal_crm.save_opening",
        command:,
        reliability_api:,
        command_executor:
      )
    end

    def ignore_opening(workspace_id:, candidate_id:, job_opening_id:, command:,
      reliability_api: Platform::Reliability::Api,
      command_executor: Platform::Reliability::CommandExecutor)
      execute_disposition_command(
        workspace_id:,
        candidate_id:,
        job_opening_id:,
        state: "ignored",
        event_type: OPENING_IGNORED,
        command_name: "personal_crm.ignore_opening",
        command:,
        reliability_api:,
        command_executor:
      )
    end

    def start_application(workspace_id:, candidate_id:, job_opening_id:, command:,
      via_posting_id: nil, channel: nil, metadata: {},
      reliability_api: Platform::Reliability::Api,
      command_executor: Platform::Reliability::CommandExecutor,
      event_reader: Platform::Reliability::EventReader)
      validate_workspace!(workspace_id)
      validate_metadata!(metadata)
      payload = {
        workspace_id:,
        candidate_id:,
        job_opening_id:,
        via_posting_id:,
        channel:
      }.compact

      execute_command(
        command_name: "personal_crm.start_application",
        payload:,
        command:,
        reliability_api:,
        command_executor:
      ) do |provenance|
        validate_candidate_and_opening!(candidate_id:, job_opening_id:, via_posting_id:)
        stream_id = opportunity_stream_id(candidate_id:, job_opening_id:)
        context = context_from_events(
          workspace_id:,
          candidate_id:,
          job_opening_id:,
          events: event_reader.fetch(aggregate_type: AGGREGATE_TYPE, aggregate_id: stream_id)
        )
        started_at = Time.current

        if context.dig(:disposition, :state) != "saved"
          append_event(
            event_type: OPENING_SAVED,
            aggregate_id: stream_id,
            effective_at: started_at,
            data: disposition_event_data(
              workspace_id:,
              candidate_id:,
              job_opening_id:,
              state: "saved",
              previous_state: context.dig(:disposition, :state),
              decided_at: started_at
            ),
            provenance:,
            reliability_api:
          )
        end

        application = {
          id: TypeID.from_uuid("application_attempt", SecureRandom.uuid).to_s,
          workspace_id:,
          candidate_id:,
          job_opening_id:,
          via_posting_id:,
          stage: "applying",
          started_at:,
          applied_at: nil,
          channel: optional_string(channel),
          next_action: "Submit application",
          next_action_at: nil,
          metadata: metadata.deep_dup
        }.compact
        append_event(
          event_type: APPLICATION_STARTED,
          aggregate_id: stream_id,
          effective_at: started_at,
          data: application,
          provenance:,
          reliability_api:
        )

        deep_freeze(
          disposition: disposition_snapshot(
            workspace_id:,
            candidate_id:,
            job_opening_id:,
            stream_id:,
            state: "saved",
            decided_at: started_at
          ),
          application:
        )
      end
    rescue Platform::Reliability::Api::Error => error
      raise ContractViolation, "reliability boundary rejected Personal CRM command: #{error.message}"
    end

    def fetch_opening_context(workspace_id:, candidate_id:, job_opening_id:,
      event_reader: Platform::Reliability::EventReader)
      validate_workspace!(workspace_id)
      stream_id = opportunity_stream_id(candidate_id:, job_opening_id:)
      context_from_events(
        workspace_id:,
        candidate_id:,
        job_opening_id:,
        events: event_reader.fetch(aggregate_type: AGGREGATE_TYPE, aggregate_id: stream_id)
      )
    end

    def execute_disposition_command(workspace_id:, candidate_id:, job_opening_id:, state:,
      event_type:, command_name:, command:, reliability_api:, command_executor:,
      event_reader: Platform::Reliability::EventReader)
      validate_workspace!(workspace_id)
      payload = { workspace_id:, candidate_id:, job_opening_id:, state: }

      execute_command(
        command_name:,
        payload:,
        command:,
        reliability_api:,
        command_executor:
      ) do |provenance|
        validate_candidate_and_opening!(candidate_id:, job_opening_id:)
        stream_id = opportunity_stream_id(candidate_id:, job_opening_id:)
        context = context_from_events(
          workspace_id:,
          candidate_id:,
          job_opening_id:,
          events: event_reader.fetch(aggregate_type: AGGREGATE_TYPE, aggregate_id: stream_id)
        )
        previous_state = context.dig(:disposition, :state)
        decided_at = Time.current

        if previous_state != state
          append_event(
            event_type:,
            aggregate_id: stream_id,
            effective_at: decided_at,
            data: disposition_event_data(
              workspace_id:,
              candidate_id:,
              job_opening_id:,
              state:,
              previous_state:,
              decided_at:
            ),
            provenance:,
            reliability_api:
          )
        end

        disposition_snapshot(
          workspace_id:,
          candidate_id:,
          job_opening_id:,
          stream_id:,
          state:,
          decided_at: previous_state == state ? context.dig(:disposition, :decided_at) : decided_at
        )
      end
    rescue Platform::Reliability::Api::Error => error
      raise ContractViolation, "reliability boundary rejected Personal CRM command: #{error.message}"
    end
    private_class_method :execute_disposition_command

    def execute_command(command_name:, payload:, command:, reliability_api:, command_executor:)
      provenance = normalized_command(command_name:, command:)
      reliability_api.receive_command(
        message_id: provenance.fetch(:message_id),
        command_id: provenance.fetch(:command_id),
        idempotency_key: provenance.fetch(:idempotency_key),
        command_name:,
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
        yield provenance
      end.fetch(:result)
    rescue KeyError => error
      raise InvalidInput, "missing command provenance field: #{error.key}"
    end
    private_class_method :execute_command

    def normalized_command(command_name:, command:)
      raise InvalidInput, "command must be an object" unless command.is_a?(Hash)

      attributes = command.to_h.symbolize_keys
      required = %i[idempotency_key principal credential actor executor interface client]
      missing = required.reject do |field|
        value = attributes[field]
        value.is_a?(String) && value.strip.present?
      end
      raise InvalidInput, "command provenance is incomplete: #{missing.join(', ')}" if missing.any?

      key = attributes.fetch(:idempotency_key).strip
      command_id = "#{command_name}:#{key}"
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
    end
    private_class_method :normalized_command

    def validate_candidate_and_opening!(candidate_id:, job_opening_id:, via_posting_id: nil)
      TalentProfile::Api.fetch_candidate(candidate_id:)
      MarketCatalog::Api.fetch_opening(opening_id: job_opening_id)
      return unless via_posting_id

      posting = MarketCatalog::Api.fetch_posting(posting_id: via_posting_id)
      return if posting.fetch(:job_opening_id) == job_opening_id

      raise InvalidInput, "via posting does not belong to the opening"
    rescue TalentProfile::Api::NotFound, MarketCatalog::Api::NotFound
      raise NotFound, "Personal CRM input not found"
    end
    private_class_method :validate_candidate_and_opening!

    def validate_workspace!(workspace_id)
      typed_id = TypeID.from_string(workspace_id.to_s)
      raise InvalidInput, "workspace_id must be an org TypeID" unless typed_id.prefix == "org"

      current = ActiveRecord::Base.connection.select_value(
        "SELECT current_setting('app.current_organization', true)"
      )
      raise InvalidInput, "workspace database scope is required" if current.blank?
      raise InvalidInput, "workspace_id does not match the database scope" unless current == typed_id.uuid.to_s
    rescue TypeID::Error
      raise InvalidInput, "workspace_id must be an org TypeID"
    end
    private_class_method :validate_workspace!

    def validate_metadata!(metadata)
      raise InvalidInput, "metadata must be an object" unless metadata.is_a?(Hash)
    end
    private_class_method :validate_metadata!

    def opportunity_stream_id(candidate_id:, job_opening_id:)
      digest = Digest::SHA256.hexdigest([ candidate_id, job_opening_id ].join("\0"))
      uuid = [ digest[0, 8], digest[8, 4], digest[12, 4], digest[16, 4], digest[20, 12] ].join("-")
      TypeID.from_uuid("opening_disposition", uuid).to_s
    end
    private_class_method :opportunity_stream_id

    def disposition_event_data(workspace_id:, candidate_id:, job_opening_id:, state:,
      previous_state:, decided_at:)
      {
        workspace_id:,
        candidate_id:,
        job_opening_id:,
        state:,
        previous_state:,
        decided_at:
      }
    end
    private_class_method :disposition_event_data

    def append_event(event_type:, aggregate_id:, effective_at:, data:, provenance:, reliability_api:)
      occurred_at = Time.current
      expected_version = Platform::Reliability::AggregateVersion.call(
        aggregate_type: AGGREGATE_TYPE,
        aggregate_id:
      )
      reliability_api.append_domain_event(
        event_type:,
        event_version: 1,
        aggregate_type: AGGREGATE_TYPE,
        aggregate_id:,
        expected_aggregate_version: expected_version,
        occurred_at:,
        effective_at:,
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
    private_class_method :append_event

    def context_from_events(workspace_id:, candidate_id:, job_opening_id:, events:)
      disposition = nil
      applications = []

      events.each do |event|
        data = event.fetch(:data).deep_symbolize_keys
        case event.fetch(:event_type)
        when OPENING_SAVED, OPENING_IGNORED
          disposition = disposition_snapshot(
            workspace_id:,
            candidate_id:,
            job_opening_id:,
            stream_id: event.fetch(:aggregate_id),
            state: data.fetch(:state),
            decided_at: data[:decided_at] || event[:effective_at] || event.fetch(:occurred_at)
          )
        when APPLICATION_STARTED
          disposition = disposition_snapshot(
            workspace_id:,
            candidate_id:,
            job_opening_id:,
            stream_id: event.fetch(:aggregate_id),
            state: "saved",
            decided_at: event[:effective_at] || event.fetch(:occurred_at)
          )
          applications << application_snapshot(data, event:)
        end
      end

      deep_freeze(disposition:, applications: applications.reverse)
    end
    private_class_method :context_from_events

    def disposition_snapshot(workspace_id:, candidate_id:, job_opening_id:, stream_id:, state:, decided_at:)
      {
        id: stream_id,
        workspace_id:,
        candidate_id:,
        job_opening_id:,
        state:,
        decided_at:
      }
    end
    private_class_method :disposition_snapshot

    def application_snapshot(data, event:)
      {
        id: data.fetch(:id),
        workspace_id: data.fetch(:workspace_id),
        candidate_id: data.fetch(:candidate_id),
        job_opening_id: data.fetch(:job_opening_id),
        via_posting_id: data[:via_posting_id],
        stage: data.fetch(:stage),
        started_at: data.fetch(:started_at),
        applied_at: data[:applied_at],
        channel: data[:channel],
        next_action: data[:next_action],
        next_action_at: data[:next_action_at],
        metadata: data.fetch(:metadata, {}),
        event_id: event.fetch(:id)
      }
    end
    private_class_method :application_snapshot

    def optional_string(value)
      return if value.nil?

      string = value.to_s.strip
      string.presence
    end
    private_class_method :optional_string

    def deep_freeze(value)
      case value
      when Hash
        value.each { |key, nested| key.freeze; deep_freeze(nested) }
      when Array
        value.each { deep_freeze(_1) }
      end
      value.freeze
    end
    private_class_method :deep_freeze
  end
end
