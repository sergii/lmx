# frozen_string_literal: true

module PersonalCrm
  class SetOpportunityDisposition
    class InvalidTransition < StandardError; end

    Result = Data.define(:record, :previous_state, :changed)

    class << self
      def call(organization_id:, candidate_id:, job_opening_id:, state:, latest_application_id: nil,
        changed_at: Time.current)
        unless OpportunityDisposition::STATES.include?(state)
          raise ArgumentError, "Unknown opportunity disposition"
        end

        record = OpportunityDisposition
          .lock
          .find_by(organization_id:, candidate_id:, job_opening_id:)
        previous_state = record&.state

        if record&.applied? && state != "applied"
          raise InvalidTransition, "An applied opportunity cannot be moved back to saved or ignored"
        end

        record ||= OpportunityDisposition.new(organization_id:, candidate_id:, job_opening_id:)
        changed = previous_state != state || record.latest_application_id != latest_application_id
        return Result.new(record:, previous_state:, changed: false) unless changed

        record.assign_attributes(state:, latest_application_id:, changed_at:)
        record.save!

        Result.new(record:, previous_state:, changed: true)
      end
    end
  end
end
