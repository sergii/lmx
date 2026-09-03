# frozen_string_literal: true

module PersonalCrm
  class OpportunityDisposition < ApplicationRecord
    self.table_name = "personal_crm_opportunity_dispositions"

    include TypedId

    uses_typed_id "opportunity_disposition"

    STATES = %w[saved ignored applied].freeze

    validates :organization_id, :candidate_id, :job_opening_id, :state, :changed_at, presence: true
    validates :state, inclusion: { in: STATES }
    validates :candidate_id, uniqueness: { scope: %i[organization_id job_opening_id] }

    def applied?
      state == "applied"
    end
  end
end
