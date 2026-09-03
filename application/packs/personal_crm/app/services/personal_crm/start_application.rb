# frozen_string_literal: true

module PersonalCrm
  class StartApplication
    class << self
      def call(organization_id:, candidate_id:, job_opening_id:, via_posting_id: nil,
        started_at: Time.current, channel: nil, metadata: {})
        Application.create!(
          organization_id:,
          candidate_id:,
          job_opening_id:,
          via_posting_id:,
          stage: "applying",
          started_at:,
          channel:,
          next_action: "Submit application",
          metadata: metadata || {}
        )
      end
    end
  end
end
