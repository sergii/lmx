# frozen_string_literal: true

module TalentProfile
  class CreateCandidate
    class << self
      def call(first_name:, last_name:, email: nil, linked_user_id: nil, profile: {}, origin: "manual", accepted_by_user_id: nil)
        workspace = WorkspaceGuard.current!
        linked_user_uuid = linked_user_id && Identifiers.uuid(linked_user_id, prefix: "user")

        Candidate.transaction do
          candidate = Candidate.create!(
            organization_id: workspace.id,
            first_name:,
            last_name:,
            email:,
            linked_user_id: linked_user_uuid
          )

          profile_version = CreateProfileVersion.call(
            candidate:,
            profile:,
            evidence_ids: [],
            origin:,
            accepted_by_user_id:
          )

          [ candidate, profile_version ]
        end
      end
    end
  end
end
