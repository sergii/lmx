# frozen_string_literal: true

module PersonalCrm
  class OpeningDisposition < ApplicationRecord
    self.table_name = "personal_crm_opening_dispositions"

    include TypedId

    uses_typed_id "opening_disposition"

    STATES = %w[saved ignored].freeze

    validates :organization_id, :candidate_id, :job_opening_id, :decided_at, presence: true
    validates :state, inclusion: { in: STATES }
    validates :candidate_id, uniqueness: { scope: %i[organization_id job_opening_id] }
  end
end
