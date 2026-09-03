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
    APPLICATION_STAGE_CHANGED = "personal_crm.application.stage_changed"
    APPLICATION_NEXT_ACTION_CHANGED = "personal_crm.application.next_action_changed"
    AGGREGATE_TYPE = "personal_crm_opportunity"
    MAX_APPLICATION_RESULTS = 500

    module_function

    def application_stages
      ApplicationProjection::STAGES.dup.freeze
    end

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
      event_reader: Platform::Reliability::EventReader,
      projector: ProjectApplicationEvent)
      workspace_uuid!(workspace_id)
      validate_metadata!(metadata)
      payload = {
        workspace_id:,
        candidate_id:,
        job_opening_id:,
        via_posting_id:,
        channel:,
        metadata: metadata.deep_dup
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
        was_saved = context.dig(:disposition, :state) == "saved"
        decided_at = was_saved ? context.dig(:disposition, :decided_at) : started_at

        unless was_saved
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
        append_result = append_event(
          event_type: APPLICATION_STARTED,
          aggregate_id: stream_id,
          effective_at: started_at,
          data: application,
          provenance:,
          reliability_api:
        )
        projector.call(event: append_result.fetch(:event))
        projected_application = find_application_projection!(
          workspace_id:,
          application_id: application.fetch(:id)
        )

        deep_freeze(
          disposition: disposition_snapshot(
            workspace_id:,
            candidate_id:,
            job_opening_id:,
            stream_id:,
            state: "saved",
            decided_at:
          ),
          application: application_projection_snapshot(projected_application)
        )
      end
    rescue ActiveRecord::RecordInvalid => error
      raise InvalidInput, error.message
    rescue Platform::Reliability::Api::Error => error
      raise ContractViolation, "reliability boundary rejected Personal CRM command: #{error.message}"
    end

    def advance_application(workspace_id:, application_id:, stage:, command:,
      reliability_api: Platform::Reliability::Api,
      command_executor: Platform::Reliability::CommandExecutor,
      projector: ProjectApplicationEvent)
      workspace_uuid!(workspace_id)
      application_id = application_id!(application_id)
      stage = required_stage!(stage)
      payload = { workspace_id:, application_id:, stage: }

      execute_command(
        command_name: "personal_crm.advance_application",
        payload:,
        command:,
        reliability_api:,
        command_executor:
      ) do |provenance|
        projection = find_application_projection!(workspace_id:, application_id:)
        next application_projection_snapshot(projection) if projection.stage == stage

        changed_at = Time.current
        applied_at = projection.applied_at
        applied_at ||= changed_at if stage == "applied"
        append_result = append_event(
          event_type: APPLICATION_STAGE_CHANGED,
          aggregate_id: opportunity_stream_id(
            candidate_id: projection.candidate_id,
            job_opening_id: projection.job_opening_id
          ),
          effective_at: changed_at,
          data: {
            workspace_id:,
            application_id:,
            candidate_id: projection.candidate_id,
            job_opening_id: projection.job_opening_id,
            from_stage: projection.stage,
            to_stage: stage,
            applied_at:,
            changed_at:
          },
          provenance:,
          reliability_api:
        )
        projector.call(event: append_result.fetch(:event))
        application_projection_snapshot(
          find_application_projection!(workspace_id:, application_id:)
        )
      end
    rescue ActiveRecord::RecordInvalid => error
      raise InvalidInput, error.message
    rescue Platform::Reliability::Api::Error => error
      raise ContractViolation, "reliability boundary rejected Personal CRM command: #{error.message}"
    end

    def set_next_action(workspace_id:, application_id:, next_action:, next_action_at:, command:,
      reliability_api: Platform::Reliability::Api,
      command_executor: Platform::Reliability::CommandExecutor,
      projector: ProjectApplicationEvent)
      workspace_uuid!(workspace_id)
      application_id = application_id!(application_id)
      next_action = optional_string(next_action)
      next_action_at = optional_time(next_action_at)
      payload = { workspace_id:, application_id:, next_action:, next_action_at: }

      execute_command(
        command_name: "personal_crm.set_next_action",
        payload:,
        command:,
        reliability_api:,
        command_executor:
      ) do |provenance|
        projection = find_application_projection!(workspace_id:, application_id:)
        if projection.next_action == next_action && projection.next_action_at == next_action_at
          next application_projection_snapshot(projection)
        end

        changed_at = Time.current
        append_result = append_event(
          event_type: APPLICATION_NEXT_ACTION_CHANGED,
          aggregate_id: opportunity_stream_id(
            candidate_id: projection.candidate_id,
            job_opening_id: projection.job_opening_id
          ),
          effective_at: changed_at,
          data: {
            workspace_id:,
            application_id:,
            candidate_id: projection.candidate_id,
            job_opening_id: projection.job_opening_id,
            previous_next_action: projection.next_action,
            previous_next_action_at: projection.next_action_at,
            next_action:,
            next_action_at:,
            changed_at:
          },
          provenance:,
          reliability_api:
        )
        projector.call(event: append_result.fetch(:event))
        application_projection_snapshot(
          find_application_projection!(workspace_id:, application_id:)
        )
      end
    rescue ActiveRecord::RecordInvalid => error
      raise InvalidInput, error.message
    rescue Platform::Reliability::Api::Error => error
      raise ContractViolation, "reliability boundary rejected Personal CRM command: #{error.message}"
    end

    def search_applications(workspace_id:, candidate_id: nil, stages: nil, limit: 200)
      organization_id = workspace_uuid!(workspace_id)
      limit = result_limit!(limit)
      relation = ApplicationProjection.where(organization_id:)
      relation = relation.where(candidate_id:) if candidate_id.present?

      if stages.present?
        normalized_stages = Array(stages).map { required_stage!(_1) }.uniq
        relation = relation.where(stage: normalized_stages)
      end

      applications = relation
        .order(Arel.sql("next_action_at ASC NULLS LAST, started_at DESC, created_at DESC"))
        .limit(limit)

      deep_freeze(applications.map { application_projection_snapshot(_1) })
    end

    def fetch_application(workspace_id:, application_id:)
      workspace_uuid!(workspace_id)
      application_projection_snapshot(
        find_application_projection!(workspace_id:, application_id: application_id!(application_id))
      )
    end

    def fetch_opening_context(workspace_id:, candidate_id:, job_opening_id:,
      event_reader: Platform::Reliability::EventReader)
      workspace_uuid!(workspace_id)
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
      workspace_uuid!(workspace_id)
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

    def workspace_uuid!(workspace_id)
      typed_id = TypeID.from_string(workspace_id.to_s)
      raise InvalidInput, "workspace_id must be an org TypeID" unless typed_id.prefix == "org"

      current = ActiveRecord::Base.connection.select_value(
        "SELECT current_setting('app.current_organization', true)"
      )
      raise InvalidInput, "workspace database scope is required" if current.blank?
      raise InvalidInput, "workspace_id does not match the database scope" unless current == typed_id.uuid.to_s

      current
    rescue TypeID::Error
      raise InvalidInput, "workspace_id must be an org TypeID"
    end
    private_class_method :workspace_uuid!

    def validate_metadata!(metadata)
      raise InvalidInput, "metadata must be an object" unless metadata.is_a?(Hash)
    end
    private_class_method :validate_metadata!

    def required_stage!(stage)
      value = stage.to_s
      return value if ApplicationProjection::STAGES.include?(value)

      raise InvalidInput, "unknown application stage"
    end
    private_class_method :required_stage!

    def application_id!(application_id)
      typed_id = TypeID.from_string(application_id.to_s)
      raise InvalidInput, "application_id must be an application_attempt TypeID" unless typed_id.prefix == "application_attempt"

      typed_id.to_s
    rescue TypeID::Error
      raise InvalidInput, "application_id must be an application_attempt TypeID"
    end
    private_class_method :application_id!

    def result_limit!(limit)
      value = Integer(limit)
      return value if value.positive? && value <= MAX_APPLICATION_RESULTS

      raise InvalidInput, "limit must be between 1 and #{MAX_APPLICATION_RESULTS}"
    rescue ArgumentError, TypeError
      raise InvalidInput, "limit must be between 1 and #{MAX_APPLICATION_RESULTS}"
    end
    private_class_method :result_limit!

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

    def find_application_projection!(workspace_id:, application_id:)
      organization_id = workspace_uuid!(workspace_id)
      ApplicationProjection.find_by!(organization_id:, application_id:)
    rescue ActiveRecord::RecordNotFound
      raise NotFound, "application not found"
    end
    private_class_method :find_application_projection!

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
          unless disposition&.dig(:state) == "saved"
            disposition = disposition_snapshot(
              workspace_id:,
              candidate_id:,
              job_opening_id:,
              stream_id: event.fetch(:aggregate_id),
              state: "saved",
              decided_at: event[:effective_at] || event.fetch(:occurred_at)
            )
          end
          applications << application_snapshot(data, event:)
        when APPLICATION_STAGE_CHANGED
          application = applications.find { _1.fetch(:id) == data.fetch(:application_id) }
          next unless application

          application[:stage] = data.fetch(:to_stage)
          application[:applied_at] = data[:applied_at]
          application[:event_id] = event.fetch(:id)
        when APPLICATION_NEXT_ACTION_CHANGED
          application = applications.find { _1.fetch(:id) == data.fetch(:application_id) }
          next unless application

          application[:next_action] = data[:next_action]
          application[:next_action_at] = data[:next_action_at]
          application[:event_id] = event.fetch(:id)
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
        started_at: event[:effective_at] || event.fetch(:occurred_at),
        applied_at: data[:applied_at],
        channel: data[:channel],
        next_action: data[:next_action],
        next_action_at: data[:next_action_at],
        metadata: data.fetch(:metadata, {}),
        event_id: event.fetch(:id)
      }
    end
    private_class_method :application_snapshot

    def application_projection_snapshot(projection)
      deep_freeze(
        id: projection.application_id,
        workspace_id: TypeID.from_uuid("org", projection.organization_id).to_s,
        candidate_id: projection.candidate_id,
        job_opening_id: projection.job_opening_id,
        via_posting_id: projection.via_posting_id,
        stage: projection.stage,
        started_at: projection.started_at,
        applied_at: projection.applied_at,
        channel: projection.channel,
        next_action: projection.next_action,
        next_action_at: projection.next_action_at,
        metadata: projection.metadata.deep_dup,
        last_event_id: projection.last_event_id,
        stream_version: projection.stream_version,
        created_at: projection.created_at,
        updated_at: projection.updated_at
      )
    end
    private_class_method :application_projection_snapshot

    def optional_string(value)
      return if value.nil?

      string = value.to_s.strip
      string.presence
    end
    private_class_method :optional_string

    def optional_time(value)
      return if value.blank?
      return value if value.respond_to?(:iso8601) && !value.is_a?(String)

      Time.iso8601(value.to_s)
    rescue ArgumentError
      raise InvalidInput, "next_action_at must be an ISO 8601 timestamp"
    end
    private_class_method :optional_time

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
