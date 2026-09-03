# frozen_string_literal: true

module TalentProfile
  class CandidateProfileVersion < ApplicationRecord
    self.table_name = "candidate_profile_versions"

    include TypedId
    include OrganizationScoped

    ORIGINS = %w[manual import agent_accepted].freeze

    uses_typed_id "candidate_profile_version"

    belongs_to :candidate, class_name: "TalentProfile::Candidate", inverse_of: :profile_versions
    has_many :profile_version_evidences,
      class_name: "TalentProfile::CandidateProfileVersionEvidence",
      inverse_of: :candidate_profile_version,
      dependent: :restrict_with_error
    has_many :candidate_evidences,
      through: :profile_version_evidences,
      source: :candidate_evidence

    validates :version_number, numericality: { only_integer: true, greater_than: 0 }
    validates :schema_version, numericality: { only_integer: true, greater_than: 0 }
    validate :profile_data_is_object
    validates :content_digest, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
    validates :origin, inclusion: { in: ORIGINS }
    validate :candidate_belongs_to_workspace
    validate :explicit_agent_acceptance

    def readonly?
      persisted?
    end

    private

    def candidate_belongs_to_workspace
      return unless candidate && organization_id
      return if candidate.organization_id == organization_id

      errors.add(:candidate, "must belong to the current workspace")
    end

    def profile_data_is_object
      return if profile_data.is_a?(Hash)

      errors.add(:profile_data, "must be a JSON object")
    end

    def explicit_agent_acceptance
      return unless origin == "agent_accepted"
      return if accepted_by_user_id.present? && accepted_at.present?

      errors.add(:base, "agent-derived profile data requires explicit acceptance")
    end
  end
end
