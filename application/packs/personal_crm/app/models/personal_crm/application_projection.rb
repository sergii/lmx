# frozen_string_literal: true

module PersonalCrm
  class ApplicationProjection < ApplicationRecord
    self.table_name = "personal_crm_application_projections"

    STAGES = %w[
      applying applied recruiter_contact screening interview offer rejected withdrawn archived
    ].freeze

    validates :organization_id, :application_id, :candidate_id, :job_opening_id,
      :stage, :started_at, :last_event_id, :stream_version, presence: true
    validates :application_id, uniqueness: { scope: :organization_id }
    validates :stage, inclusion: { in: STAGES }
    validates :stream_version, numericality: { only_integer: true, greater_than: 0 }
    validate :metadata_is_object

    private

    def metadata_is_object
      errors.add(:metadata, "must be a JSON object") unless metadata.is_a?(Hash)
    end
  end
end
