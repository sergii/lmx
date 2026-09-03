# frozen_string_literal: true

module TalentProfile
  class CreateProfileVersion
    class << self
      def call(candidate: nil, candidate_id: nil, profile:, evidence_ids: [], origin: "manual", accepted_by_user_id: nil)
        workspace = WorkspaceGuard.current!
        candidate ||= find_candidate(workspace, candidate_id)
        ensure_candidate_workspace!(candidate, workspace)

        raise ArgumentError, "profile must be a hash" unless profile.is_a?(Hash)

        normalized_profile = CanonicalJson.normalize(profile)
        evidence_records = find_evidences(workspace, candidate, evidence_ids)
        acceptance = acceptance_attributes(origin, accepted_by_user_id)

        candidate.with_lock do
          version = CandidateProfileVersion.create!(
            organization_id: workspace.id,
            candidate:,
            version_number: next_version_number(candidate, workspace),
            schema_version: 1,
            profile_data: normalized_profile,
            content_digest: CanonicalJson.digest(normalized_profile),
            origin:,
            **acceptance
          )

          evidence_records.each do |evidence|
            CandidateProfileVersionEvidence.create!(
              organization_id: workspace.id,
              candidate_profile_version: version,
              candidate_evidence: evidence
            )
          end

          version
        end
      end

      private

      def find_candidate(workspace, candidate_id)
        Candidate.for_organization(workspace).find(Identifiers.uuid(candidate_id, prefix: "candidate"))
      end

      def ensure_candidate_workspace!(candidate, workspace)
        return if candidate.organization_id == workspace.id

        raise ActiveRecord::RecordNotFound, "Candidate does not belong to the current workspace"
      end

      def find_evidences(workspace, candidate, evidence_ids)
        ids = evidence_ids.map { Identifiers.uuid(_1, prefix: "candidate_evidence") }.uniq
        return [] if ids.empty?

        records = CandidateEvidence.for_organization(workspace).where(candidate_id: candidate.id, id: ids).to_a
        return records if records.size == ids.size

        raise ActiveRecord::RecordNotFound, "Evidence does not belong to the candidate in the current workspace"
      end

      def next_version_number(candidate, workspace)
        CandidateProfileVersion.for_organization(workspace).where(candidate_id: candidate.id).maximum(:version_number).to_i + 1
      end

      def acceptance_attributes(origin, accepted_by_user_id)
        return {} unless origin.to_s == "agent_accepted"
        raise ArgumentError, "accepted_by_user_id is required for agent_accepted origin" if accepted_by_user_id.blank?

        {
          accepted_by_user_id: Identifiers.uuid(accepted_by_user_id, prefix: "user"),
          accepted_at: Time.current
        }
      end
    end
  end
end
