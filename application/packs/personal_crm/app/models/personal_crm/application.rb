# frozen_string_literal: true

module PersonalCrm
  class Application < ApplicationRecord
    self.table_name = "personal_crm_applications"

    include TypedId

    uses_typed_id "application_attempt"

    STAGES = %w[
      applying applied recruiter_contact screening interview offer rejected withdrawn archived
    ].freeze

    validates :organization_id, :candidate_id, :job_opening_id, :started_at, presence: true
    validates :stage, inclusion: { in: STAGES }
    validate :metadata_is_object

    private

    def metadata_is_object
      errors.add(:metadata, "must be a JSON object") unless metadata.is_a?(Hash)
    end
  end
end
