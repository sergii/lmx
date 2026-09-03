# frozen_string_literal: true

module TalentProfile
  class RecordEvidence
    class << self
      def call(candidate_id:, source_type:, claim:, source_reference: nil, confidence: nil, observed_at: nil, provenance: {})
        workspace = WorkspaceGuard.current!
        candidate = find_candidate(workspace, candidate_id)

        CandidateEvidence.create!(
          organization_id: workspace.id,
          candidate:,
          source_type:,
          source_reference:,
          claim:,
          confidence:,
          observed_at:,
          provenance:
        )
      end

      private

      def find_candidate(workspace, candidate_id)
        Candidate.for_organization(workspace).find(Identifiers.uuid(candidate_id, prefix: "candidate"))
      end
    end
  end
end
