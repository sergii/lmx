# frozen_string_literal: true

module TalentProfile
  class Candidate < ApplicationRecord
    self.table_name = "candidates"

    include TypedId
    include OrganizationScoped

    uses_typed_id "candidate"

    has_many :profile_versions,
      -> { order(version_number: :desc) },
      class_name: "TalentProfile::CandidateProfileVersion",
      inverse_of: :candidate,
      dependent: :restrict_with_error
    has_many :evidences,
      class_name: "TalentProfile::CandidateEvidence",
      inverse_of: :candidate,
      dependent: :restrict_with_error

    validates :first_name, :last_name, presence: true
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

    normalizes :email, with: -> { _1.strip.downcase.presence }

    def latest_profile_version
      profile_versions.first
    end
  end
end
