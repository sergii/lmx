# frozen_string_literal: true

module Intelligence
  class RecordMatchAssessment
    class InvalidInput < StandardError; end
    class ContractViolation < StandardError; end

    class << self
      def call(
        workspace_id:,
        candidate_id:,
        candidate_profile_version_id:,
        job_opening_id:,
        opening_evidence_cutoff:,
        scoring_policy_version:,
        opportunity_score: nil,
        action_priority: nil,
        score_details: {},
        strengths: [],
        gaps: [],
        risks: [],
        recommendation: nil,
        interview_angles: [],
        evidence_references: [],
        processor_kind: nil,
        processor_key: nil,
        processor_version: nil,
        model_name: nil,
        model_version: nil,
        generated_at: Time.current,
        talent_api: TalentProfile::Api,
        market_api: MarketCatalog::Api
      )
        workspace_uuid = Identifiers.uuid(workspace_id, prefix: "org")
        profile = talent_api.fetch_profile_version(
          candidate_id:,
          profile_version_id: candidate_profile_version_id
        )
        opening = market_api.fetch_opening(opening_id: job_opening_id)

        verify_profile_contract!(profile, candidate_id:, candidate_profile_version_id:)
        verify_opening_contract!(opening, job_opening_id:)

        MatchAssessment.transaction do
          lock_pair!(workspace_uuid:, candidate_id:, job_opening_id:)
          version_number = next_version_number(workspace_uuid:, candidate_id:, job_opening_id:)

          MatchAssessment.create!(
            organization_id: workspace_uuid,
            candidate_id: profile.fetch(:candidate_id),
            candidate_profile_version_id: profile.fetch(:id),
            candidate_profile_content_digest: profile.fetch(:content_digest),
            job_opening_id: opening.fetch(:id),
            opening_evidence_cutoff:,
            opening_snapshot: deep_dup(opening),
            version_number:,
            opportunity_score:,
            action_priority:,
            score_details: deep_dup(score_details),
            strengths: deep_dup(strengths),
            gaps: deep_dup(gaps),
            risks: deep_dup(risks),
            recommendation:,
            interview_angles: deep_dup(interview_angles),
            evidence_references: deep_dup(evidence_references),
            scoring_policy_version:,
            processor_kind:,
            processor_key:,
            processor_version:,
            processor_model_name: model_name,
            model_version:,
            generated_at:
          )
        end
      rescue ArgumentError => error
        raise InvalidInput, error.message
      end

      private

      def verify_profile_contract!(profile, candidate_id:, candidate_profile_version_id:)
        return if profile.fetch(:candidate_id) == candidate_id && profile.fetch(:id) == candidate_profile_version_id

        raise ContractViolation, "Talent Profile returned a different candidate/profile identity"
      end

      def verify_opening_contract!(opening, job_opening_id:)
        return if opening.fetch(:id) == job_opening_id

        raise ContractViolation, "Market Catalog returned a different opening identity"
      end

      def lock_pair!(workspace_uuid:, candidate_id:, job_opening_id:)
        key = [ workspace_uuid, candidate_id, job_opening_id ].join(":")
        connection = MatchAssessment.connection
        connection.execute(
          "SELECT pg_advisory_xact_lock(hashtextextended(#{connection.quote(key)}, 0))"
        )
      end

      def next_version_number(workspace_uuid:, candidate_id:, job_opening_id:)
        MatchAssessment
          .where(organization_id: workspace_uuid, candidate_id:, job_opening_id:)
          .maximum(:version_number).to_i + 1
      end

      def deep_dup(value)
        case value
        when Hash
          value.to_h { |key, nested| [ key, deep_dup(nested) ] }
        when Array
          value.map { deep_dup(_1) }
        else
          value.duplicable? ? value.dup : value
        end
      end
    end
  end
end
