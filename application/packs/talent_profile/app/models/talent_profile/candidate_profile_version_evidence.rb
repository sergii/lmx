# frozen_string_literal: true

module TalentProfile
  class CandidateProfileVersionEvidence < ApplicationRecord
    self.table_name = "candidate_profile_version_evidences"

    include OrganizationScoped

    belongs_to :candidate_profile_version,
      class_name: "TalentProfile::CandidateProfileVersion",
      inverse_of: :profile_version_evidences
    belongs_to :candidate_evidence,
      class_name: "TalentProfile::CandidateEvidence"

    validate :records_belong_to_workspace

    def readonly?
      persisted?
    end

    private

    def records_belong_to_workspace
      return unless organization_id

      if candidate_profile_version && candidate_profile_version.organization_id != organization_id
        errors.add(:candidate_profile_version, "must belong to the current workspace")
      end

      if candidate_evidence && candidate_evidence.organization_id != organization_id
        errors.add(:candidate_evidence, "must belong to the current workspace")
      end
    end
  end
end
