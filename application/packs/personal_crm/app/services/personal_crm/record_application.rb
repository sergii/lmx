# frozen_string_literal: true

module PersonalCrm
  class RecordApplication
    Result = Data.define(:record, :created)

    class << self
      def call(organization_id:, candidate_id:, job_opening_id:, via_posting_id: nil,
        applied_at: Time.current, channel: nil, metadata: {})
        existing = Application
          .lock
          .where(organization_id:, candidate_id:, job_opening_id:)
          .order(attempt_number: :desc)
          .first
        return Result.new(record: existing, created: false) if existing

        record = Application.create!(
          organization_id:,
          candidate_id:,
          job_opening_id:,
          via_posting_id:,
          attempt_number: 1,
          applied_at:,
          current_stage: "applied",
          channel:,
          metadata: metadata || {}
        )

        Result.new(record:, created: true)
      end
    end
  end
end
