# frozen_string_literal: true

module PersonalCrm
  module Api
    class Error < StandardError; end
    class InvalidInput < Error; end
    class InvalidTransition < Error; end
    class NotFound < Error; end
    class ContractViolation < Error; end

    DISPOSITION_CHANGED = "personal_crm.opportunity_disposition.changed"
    APPLICATION_RECORDED = "personal_crm.application.recorded"

    module_function

    def save_opportunity(workspace_id:, candidate_id:, job_opening_id:, command:,
      talent_api: TalentProfile::Api, market_api: MarketCatalog::Api,
      reliability_api: Platform::Reliability::Api)
      change_disposition(
        workspace_id:,
        candidate_id:,
        job_opening_id:,
        state: "saved",
        command:,
        talent_api:,
        market_api:,
        reliability_api:
      )
    end

    def ignore_opportunity(workspace_id:, candidate_id:, job_opening_id:, command:,
      talent_api: TalentProfile::Api, market_api: MarketCatalog::Api,
      reliability_api: Platform::Reliability::Api)
      change_disposition(
        workspace_id:,
        candidate_id:,
        job_opening_id:,
        state: "ignored",
        command:,
        talent_api:,
        market_api:,
        reliability_api:
      )
    end

    def apply_to_opportunity(workspace_id:, candidate_id:, job_opening_id:, command:,
      via_posting_id: nil, applied_at: Time.current, channel: "web", metadata: {},
      talent_api: TalentProfile::Api, market_api: MarketCatalog::Api,
      reliability_api: Platform::Reliability::Api)
      organization_id = workspace_uuid(workspace_id)
      command_attributes = normalize_command(command)
      validate_command!(command_attributes)
      validate_opportunity!(candidate_id:, job_opening_id:, via_posting_id:, talent_api:, market_api:)

      ActiveRecord::Base.transaction do
        application_result = RecordApplication.call(
          organization_id:,
          candidate_id:,
          job_opening_id:,
          via_posting_id:,
          applied_at:,
          channel:,
          metadata:
        )
        application = application_result.record

        if application_result.created
          append_event(
            reliability_api:,
            event_type: APPLICATION_RECORDED,
            aggregate_type: "PersonalCrm::Application",
            aggregate_id: application.typed_id,
            expected_aggregate_version: 0,
            occurred_at: applied_at,
            effective_at: applied_at,
            evidence_references: [ via_posting_id ].compact,
            command: command_attributes,
            data: application_event_data(application)
          )
        end

        disposition_result = SetOpportunityDisposition.call(
          organization_id:,
          candidate_id:,
          job_opening_id:,
          state: "applied",
          latest_application_id: application.typed_id,
          changed_at: applied_at
        )

        if disposition_result.changed
          append_disposition_event(
            disposition_result,
            reliability_api:,
            command: command_attributes,
            occurred_at: applied_at
          )
        end

        opportunity_snapshot(disposition_result.record, application:)
      end
    rescue SetOpportunityDisposition::InvalidTransition => error
      raise InvalidTransition, error.message
    rescue TalentProfile::Api::NotFound, MarketCatalog::Api::NotFound
      raise NotFound, "candidate or opening not found"
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ArgumentError => error
      raise InvalidInput, error.message
    rescue Platform::Reliability::Api::Error => error
      raise ContractViolation, "reliability boundary rejected Personal CRM change: #{error.message}"
    end

    def fetch_opportunity(workspace_id:, candidate_id:, job_opening_id:)
      organization_id = workspace_uuid(workspace_id)
      disposition = OpportunityDisposition.find_by(
        organization_id:,
        candidate_id:,
        job_opening_id:
      )
      application = Application
        .where(organization_id:, candidate_id:, job_opening_id:)
        .order(attempt_number: :desc)
        .first

      opportunity_snapshot(disposition, application:)
    rescue ArgumentError => error
      raise InvalidInput, error.message
    end

    def fetch_application(application_id:, workspace_id: nil)
      organization_id = workspace_id ? workspace_uuid(workspace_id) : current_organization_id!
      application_uuid = Identifiers.uuid(application_id, prefix: "application_attempt")
      application = Application.find_by!(organization_id:, id: application_uuid)

      application_snapshot(application)
    rescue ArgumentError, ActiveRecord::RecordNotFound
      raise NotFound, "application not found"
    end

    def change_disposition(workspace_id:, candidate_id:, job_opening_id:, state:, command:,
      talent_api:, market_api:, reliability_api:)
      organization_id = workspace_uuid(workspace_id)
      command_attributes = normalize_command(command)
      validate_command!(command_attributes)
      validate_opportunity!(candidate_id:, job_opening_id:, talent_api:, market_api:)
      changed_at = Time.current

      ActiveRecord::Base.transaction do
        result = SetOpportunityDisposition.call(
          organization_id:,
          candidate_id:,
          job_opening_id:,
          state:,
          changed_at:
        )

        append_disposition_event(
          result,
          reliability_api:,
          command: command_attributes,
          occurred_at: changed_at
        ) if result.changed

        opportunity_snapshot(result.record, application: nil)
      end
    rescue SetOpportunityDisposition::InvalidTransition => error
      raise InvalidTransition, error.message
    rescue TalentProfile::Api::NotFound, MarketCatalog::Api::NotFound
      raise NotFound, "candidate or opening not found"
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ArgumentError => error
      raise InvalidInput, error.message
    rescue Platform::Reliability::Api::Error => error
      raise ContractViolation, "reliability boundary rejected Personal CRM change: #{error.message}"
    end
    private_class_method :change_disposition

    def validate_opportunity!(candidate_id:, job_opening_id:, talent_api:, market_api:, via_posting_id: nil)
      candidate = talent_api.fetch_candidate(candidate_id:)
      opening = market_api.fetch_opening(opening_id: job_opening_id)
      return unless via_posting_id

      posting = market_api.fetch_posting(posting_id: via_posting_id)
      return if posting.fetch(:job_opening_id) == opening.fetch(:id)

      raise InvalidInput, "via_posting_id does not belong to the selected opening"
    end
    private_class_method :validate_opportunity!

    def append_disposition_event(result, reliability_api:, command:, occurred_at:)
      disposition = result.record
      append_event(
        reliability_api:,
        event_type: DISPOSITION_CHANGED,
        aggregate_type: "PersonalCrm::OpportunityDisposition",
        aggregate_id: disposition.typed_id,
        expected_aggregate_version: Platform::Reliability::AggregateVersion.call(
          aggregate_type: "PersonalCrm::OpportunityDisposition",
          aggregate_id: disposition.typed_id
        ),
        occurred_at:,
        effective_at: occurred_at,
        command:,
        data: {
          disposition_id: disposition.typed_id,
          candidate_id: disposition.candidate_id,
          job_opening_id: disposition.job_opening_id,
          previous_state: result.previous_state,
          state: disposition.state,
          latest_application_id: disposition.latest_application_id,
          changed_at: disposition.changed_at
        }
      )
    end
    private_class_method :append_disposition_event

    def append_event(reliability_api:, event_type:, aggregate_type:, aggregate_id:,
      expected_aggregate_version:, occurred_at:, effective_at:, command:, data:,
      evidence_references: [])
      reliability_api.append_domain_event(
        event_type:,
        event_version: 1,
        aggregate_type:,
        aggregate_id:,
        expected_aggregate_version:,
        occurred_at:,
        effective_at:,
        principal: command.fetch(:principal),
        credential: command.fetch(:credential),
        actor: command.fetch(:actor),
        executor: command.fetch(:executor),
        interface: command.fetch(:interface),
        client: command.fetch(:client),
        evidence_references:,
        correlation_id: command[:correlation_id],
        causation_id: command[:causation_id],
        command_id: command.fetch(:command_id),
        idempotency_key: command.fetch(:idempotency_key),
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

    def application_event_data(application)
      {
        application_id: application.typed_id,
        candidate_id: application.candidate_id,
        job_opening_id: application.job_opening_id,
        via_posting_id: application.via_posting_id,
        attempt_number: application.attempt_number,
        current_stage: application.current_stage,
        channel: application.channel,
        applied_at: application.applied_at
      }.compact.freeze
    end
    private_class_method :application_event_data

    def opportunity_snapshot(disposition, application:)
      {
        disposition: disposition && disposition_snapshot(disposition),
        application: application && application_snapshot(application)
      }.freeze
    end
    private_class_method :opportunity_snapshot

    def disposition_snapshot(disposition)
      {
        id: disposition.typed_id,
        candidate_id: disposition.candidate_id,
        job_opening_id: disposition.job_opening_id,
        state: disposition.state,
        latest_application_id: disposition.latest_application_id,
        changed_at: disposition.changed_at
      }.freeze
    end
    private_class_method :disposition_snapshot

    def application_snapshot(application)
      {
        id: application.typed_id,
        candidate_id: application.candidate_id,
        job_opening_id: application.job_opening_id,
        via_posting_id: application.via_posting_id,
        attempt_number: application.attempt_number,
        applied_at: application.applied_at,
        current_stage: application.current_stage,
        channel: application.channel,
        next_action: application.next_action,
        next_action_at: application.next_action_at,
        metadata: deep_freeze(application.metadata.deep_dup),
        created_at: application.created_at,
        updated_at: application.updated_at
      }.freeze
    end
    private_class_method :application_snapshot

    def normalize_command(command)
      raise InvalidInput, "command must be an object" unless command.is_a?(Hash)

      command.each_with_object({}) do |(key, value), normalized|
        unless key.is_a?(String) || key.is_a?(Symbol)
          raise InvalidInput, "command keys must be strings or symbols"
        end

        normalized[key.to_sym] = value
      end
    end
    private_class_method :normalize_command

    def validate_command!(command)
      required = %i[command_id idempotency_key principal credential actor executor interface client]
      missing = required.reject do |field|
        value = command[field]
        value.is_a?(String) && value.strip.present?
      end
      return if missing.empty?

      raise InvalidInput, "command provenance is incomplete: #{missing.join(', ')}"
    end
    private_class_method :validate_command!

    def workspace_uuid(value)
      Identifiers.uuid(value, prefix: "org")
    rescue ArgumentError => error
      raise InvalidInput, error.message
    end
    private_class_method :workspace_uuid

    def current_organization_id!
      value = ApplicationRecord.connection.select_value(
        "SELECT current_setting('app.current_organization', true)"
      ).to_s
      raise InvalidInput, "workspace context is required" if value.blank?

      value
    end
    private_class_method :current_organization_id!

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
