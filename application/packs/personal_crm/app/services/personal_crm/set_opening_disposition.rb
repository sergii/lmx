# frozen_string_literal: true

module PersonalCrm
  class SetOpeningDisposition
    class << self
      def call(organization_id:, candidate_id:, job_opening_id:, state:, decided_at: Time.current)
        raise ArgumentError, "unknown opening disposition" unless OpeningDisposition::STATES.include?(state)

        OpeningDisposition.transaction do
          disposition = OpeningDisposition
            .where(organization_id:, candidate_id:, job_opening_id:)
            .lock
            .first
          previous_state = disposition&.state

          if disposition
            disposition.update!(state:, decided_at:) if previous_state != state
          else
            disposition = OpeningDisposition.create!(
              organization_id:,
              candidate_id:,
              job_opening_id:,
              state:,
              decided_at:
            )
          end

          {
            disposition:,
            changed: previous_state != state,
            previous_state:
          }.freeze
        end
      end
    end
  end
end
