# frozen_string_literal: true

module Intelligence
  module Api
    class Error < StandardError; end
    class InvalidInput < Error; end
    class NotFound < Error; end
    class ContractViolation < Error; end

    MATCH_ASSESSMENT_RECORDED = "intelligence.match_assessment.recorded"

    module_function

    def assess_match(workspace_id:, assessment:, command:, reliability_api: Platform::Reliability::Api)
      assessment_attributes = normalize_public_hash(assessment, label: "assessment")
      command_attributes = normalize_public_hash(command, label: "command")
      validate_command_provenance!(command_attributes)
      recorded_at = Time.current

      snapshot = ActiveRecord::Base.transaction do
        recorded = record_match_assessment(workspace_id:, **assessment_attributes)
        payload = match_recorded_payload(recorded)

        reliability_api.append_domain_event(
          event_type: MATCH_ASSESSMENT_RECORDED,
          event_version: 1,
          aggregate_type: "match_assessment",
          aggregate_id: recorded.fetch(:id),
          expected_aggregate_version: 0,
          occurred_at: recorded_at,
          effective_at: recorded.fetch(:generated_at),
          principal: command_attributes.fetch(:principal),
          credential: command_attributes.fetch(:credential),
          actor: command_attributes.fetch(:actor),
          executor: command_attributes.fetch(:executor),
          interface: command_attributes.fetch(:interface),
          client: command_attributes.fetch(:client),
          evidence_references: recorded.fetch(:evidence_references),
          correlation_id: command_attributes[:correlation_id],
          causation_id: command_attributes[:causation_id],
          command_id: command_attributes.fetch(:command_id),
          idempotency_key: command_attributes.fetch(:idempotency_key),
          data: payload,
          outbox_messages: [
            {
              message_type: MATCH_ASSESSMENT_RECORDED,
              message_version: 1,
              payload: payload,
              available_at: recorded_at
            }
          ]
        )

        recorded
      end

      snapshot
    rescue KeyError => error
      raise InvalidInput, "missing command provenance field: #{error.key}"
    rescue Platform::Reliability::Api::Error => error
      raise ContractViolation, "reliability boundary rejected match assessment: #{error.message}"
    end

    def record_match_assessment(**attributes)
      assessment_snapshot(RecordMatchAssessment.call(**attributes))
    rescue RecordMatchAssessment::InvalidInput, ActiveRecord::RecordInvalid => error
      raise InvalidInput, error.message
    rescue RecordMatchAssessment::ContractViolation => error
      raise ContractViolation, error.message
    rescue TalentProfile::Api::NotFound, MarketCatalog::Api::NotFound
      raise NotFound, "assessment input not found"
    end

    def fetch_match_assessment(workspace_id:, assessment_id:)
      workspace_uuid = Identifiers.uuid(workspace_id, prefix: "org")
      assessment_uuid = Identifiers.uuid(assessment_id, prefix: "match_assessment")
      assessment = MatchAssessment.find_by!(organization_id: workspace_uuid, id: assessment_uuid)

      assessment_snapshot(assessment)
    rescue ArgumentError, ActiveRecord::RecordNotFound
      raise NotFound, "match assessment not found"
    end

    def fetch_latest_match(workspace_id:, candidate_id:, job_opening_id:)
      workspace_uuid = Identifiers.uuid(workspace_id, prefix: "org")
      assessment = MatchAssessment
        .where(organization_id: workspace_uuid, candidate_id:, job_opening_id:)
        .order(version_number: :desc)
        .first!

      assessment_snapshot(assessment)
    rescue ArgumentError, ActiveRecord::RecordNotFound
      raise NotFound, "match assessment not found"
    end

    def assessment_snapshot(assessment)
      {
        id: assessment.typed_id,
        workspace_id: TypeID.from_uuid("org", assessment.organization_id).to_s,
        candidate_id: assessment.candidate_id,
        candidate_profile_version_id: assessment.candidate_profile_version_id,
        candidate_profile_content_digest: assessment.candidate_profile_content_digest,
        job_opening_id: assessment.job_opening_id,
        opening_evidence_cutoff: assessment.opening_evidence_cutoff,
        opening_snapshot: deep_freeze(assessment.opening_snapshot.deep_dup),
        version_number: assessment.version_number,
        opportunity_score: assessment.opportunity_score&.to_f,
        action_priority: assessment.action_priority&.to_f,
        score_details: deep_freeze(assessment.score_details.deep_dup),
        strengths: deep_freeze(assessment.strengths.deep_dup),
        gaps: deep_freeze(assessment.gaps.deep_dup),
        risks: deep_freeze(assessment.risks.deep_dup),
        recommendation: assessment.recommendation,
        interview_angles: deep_freeze(assessment.interview_angles.deep_dup),
        evidence_references: deep_freeze(assessment.evidence_references.deep_dup),
        scoring_policy_version: assessment.scoring_policy_version,
        processor: compact_frozen_hash(
          kind: assessment.processor_kind,
          key: assessment.processor_key,
          version: assessment.processor_version,
          model_name: assessment.processor_model_name,
          model_version: assessment.model_version
        ),
        generated_at: assessment.generated_at,
        created_at: assessment.created_at
      }.freeze
    end
    private_class_method :assessment_snapshot

    def normalize_public_hash(value, label:)
      raise InvalidInput, "#{label} must be an object" unless value.is_a?(Hash)

      value.each_with_object({}) do |(key, nested), normalized|
        unless key.is_a?(String) || key.is_a?(Symbol)
          raise InvalidInput, "#{label} keys must be strings or symbols"
        end

        normalized[key.to_sym] = nested
      end
    end
    private_class_method :normalize_public_hash

    def validate_command_provenance!(command)
      required = %i[command_id idempotency_key principal credential actor executor interface client]
      missing = required.reject do |field|
        value = command[field]
        value.is_a?(String) && value.strip.present?
      end
      return if missing.empty?

      raise InvalidInput, "command provenance is incomplete: #{missing.join(', ')}"
    end
    private_class_method :validate_command_provenance!

    def match_recorded_payload(assessment)
      {
        assessment_id: assessment.fetch(:id),
        candidate_id: assessment.fetch(:candidate_id),
        candidate_profile_version_id: assessment.fetch(:candidate_profile_version_id),
        job_opening_id: assessment.fetch(:job_opening_id),
        version_number: assessment.fetch(:version_number),
        opportunity_score: assessment.fetch(:opportunity_score),
        action_priority: assessment.fetch(:action_priority),
        scoring_policy_version: assessment.fetch(:scoring_policy_version),
        generated_at: assessment.fetch(:generated_at)
      }.freeze
    end
    private_class_method :match_recorded_payload

    def compact_frozen_hash(**attributes)
      attributes.compact.freeze
    end
    private_class_method :compact_frozen_hash

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
