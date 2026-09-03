# frozen_string_literal: true

module PersonalCrm
  class Application < ApplicationRecord
    self.table_name = "personal_crm_applications"

    include TypedId

    uses_typed_id "application_attempt"

    validates :organization_id, :candidate_id, :job_opening_id, :applied_at, :current_stage, presence: true
    validates :attempt_number, numericality: { only_integer: true, greater_than: 0 }
    validates :attempt_number, uniqueness: { scope: %i[organization_id candidate_id job_opening_id] }
    validate :metadata_is_object

    private

    def metadata_is_object
      errors.add(:metadata, "must be a JSON object") unless metadata.is_a?(Hash)
    end
  end
end
