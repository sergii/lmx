# frozen_string_literal: true

module PersonalCrm
  module Api
    class Error < StandardError; end
    class InvalidInput < Error; end
    class NotFound < Error; end
    class ContractViolation < Error; end

    OPENING_SAVED = "personal_crm.opening.saved"
    OPENING_IGNORED = "personal_crm.opening.ignored"
    APPLICATION_STARTED = "personal_crm.application.started"

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
      command_executor: Platform::Reliability::CommandExecutor)
      organization_id = workspace_uuid!(workspace_id)
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
        started_at = Time.current

        disposition_change = SetOpeningDisposition.call(
          organization_id:,
          candidate_id:,
          job_opening_id:,
          state: "saved",
          decided_at: started_at
        )
        if disposition_change.fetch(:changed)
          emit_disposition_event(
            disposition_change:,
            event_type: OPENING_SAVED,
            provenance:,
            reliability_api:
          )
        end

        application = StartApplication.call(
          organization_id:,
          candidate_id:,
          job_opening_id:,
          via_posting_id:,
          started_at:,
          channel:,
          metadata:
        )
        emit_application_started(application:, provenance:, reliability_api:)

        {
          disposition: disposition_snapshot(disposition_change.fetch(:disposition)),
          application: application_snapshot(application)
        }.freeze
      end
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      raise InvalidInput, error.message
    rescue Platform::Reliability::Api::Error => error
      raise ContractViolation, "reliability boundary rejected Personal CRM command: #{error.message}"
    end

    def fetch_opening_context(workspace_id:, candidate_id:, job_opening_id:)
      organization_id = workspace_uuid!(workspace_id)
      disposition = OpeningDisposition.find_by(organization_id:, candidate_id:, job_opening_id:)
      applications = Application
        .where(organization_id:, candidate_id:, job_opening_id:)
        .order(started_at: :desc, created_at: :desc, id: :desc)

      deep_freeze(
        disposition: disposition && disposition_snapshot(disposition),
        applications: applications.map { application_snapshot(_1) }
      )
    end

    def execute_disposition_command(workspace_id:, candidate_id:, job_opening_id:, state:,
      event_type:, command_name:, command:, reliability_api:, command_executor:)
      organization_id = workspace_uuid!(workspace_id)
      payload = { workspace_id:, candidate_id:, job_opening_id:, state: }

      execute_command(
        command_name:,
        payload:,
        command:,
        reliability_api:,
        command_executor:
      ) do |provenance|
        validate_candidate_and_opening!(candidate_id:, job_opening_id:)
        change = SetOpeningDisposition.call(
          organization_id:,
          candidate_id:,
          job_opening_id:,
          state:
        )
        if change.fetch(:changed)
          emit_disposition_event(
            disposition_change: change,
            event_type:,
            provenance:,
            reliability_api:
          )
        end

        disposition_snapshot(change.fetch(:disposition))
      end
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      raise InvalidInput, error.message
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

    def emit_disposition_event(disposition_change:, event_type:, provenance:, reliability_api:)
      disposition = disposition_change.fetch(:disposition)
      data = {
        disposition_id: disposition.typed_id,
        candidate_id: disposition.candidate_id,
        job_opening_id: disposition.job_opening_id,
        previous_state: disposition_change[:previous_state],
        state: disposition.state,
        decided_at: disposition.decided_at
      }
      append_event(
        event_type:,
        aggregate_type: "personal_crm_opening_disposition",
        aggregate_id: disposition.typed_id,
        effective_at: disposition.decided_at,
        data:,
        provenance:,
        reliability_api:
      )
    end
    private_class_method :emit_disposition_event

    def emit_application_started(application:, provenance:, reliability_api:)
      data = {
        application_id: application.typed_id,
        candidate_id: application.candidate_id,
        job_opening_id: application.job_opening_id,
        via_posting_id: application.via_posting_id,
        stage: application.stage,
        started_at: application.started_at,
        next_action: application.next_action
      }.compact
      append_event(
        event_type: APPLICATION_STARTED,
        aggregate_type: "personal_crm_application",
        aggregate_id: application.typed_id,
        effective_at: application.started_at,
        data:,
        provenance:,
        reliability_api:
      )
    end
    private_class_method :emit_application_started

    def append_event(event_type:, aggregate_type:, aggregate_id:, effective_at:, data:, provenance:,
      reliability_api:)
      occurred_at = Time.current
      expected_version = Platform::Reliability::AggregateVersion.call(
        aggregate_type:,
        aggregate_id:
      )
      reliability_api.append_domain_event(
        event_type:,
        event_version: 1,
        aggregate_type:,
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

    def workspace_uuid!(workspace_id)
      typed_id = TypeID.from_string(workspace_id.to_s)
      raise InvalidInput, "workspace_id must be an org TypeID" unless typed_id.prefix == "org"

      current = ActiveRecord::Base.connection.select_value(
        "SELECT current_setting('app.current_organization', true)"
      )
      raise InvalidInput, "workspace database scope is required" if current.blank?
      raise InvalidInput, "workspace_id does not match the database scope" unless current == typed_id.uuid.to_s

      typed_id.uuid.to_s
    rescue TypeID::Error
      raise InvalidInput, "workspace_id must be an org TypeID"
    end
    private_class_method :workspace_uuid!

    def disposition_snapshot(disposition)
      {
        id: disposition.typed_id,
        workspace_id: TypeID.from_uuid("org", disposition.organization_id).to_s,
        candidate_id: disposition.candidate_id,
        job_opening_id: disposition.job_opening_id,
        state: disposition.state,
        decided_at: disposition.decided_at,
        created_at: disposition.created_at,
        updated_at: disposition.updated_at
      }.freeze
    end
    private_class_method :disposition_snapshot

    def application_snapshot(application)
      {
        id: application.typed_id,
        workspace_id: TypeID.from_uuid("org", application.organization_id).to_s,
        candidate_id: application.candidate_id,
        job_opening_id: application.job_opening_id,
        via_posting_id: application.via_posting_id,
        stage: application.stage,
        started_at: application.started_at,
        applied_at: application.applied_at,
        channel: application.channel,
        next_action: application.next_action,
        next_action_at: application.next_action_at,
        metadata: deep_freeze(application.metadata.deep_dup),
        created_at: application.created_at,
        updated_at: application.updated_at
      }.freeze
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
