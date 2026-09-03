# frozen_string_literal: true

module MarketCatalog
  class ReconcilePostingLifecycle
    DEFINITIVE_PRESENCE_STATES = %w[present missing explicit_closed].freeze
    ABSENCE_PRESENCE_STATES = %w[missing explicit_closed].freeze
    ACTIVE_LIFECYCLE_STATES = %w[present reappeared].freeze

    class << self
      def call(posting_id:)
        new(posting_id:).call
      end
    end

    def initialize(posting_id:)
      @posting = find_record(JobPosting, posting_id, "posting_")
    end

    def call
      posting.with_lock do
        snapshots = definitive_snapshots
        next if snapshots.empty?

        posting.update!(projected_attributes(snapshots))
      end

      reconcile_opening
      posting
    end

    private

    attr_reader :posting

    def definitive_snapshots
      posting.snapshots
        .where(presence_state: DEFINITIVE_PRESENCE_STATES)
        .order(observed_at: :desc, created_at: :desc, id: :desc)
        .to_a
    end

    def projected_attributes(snapshots)
      state = projected_state(snapshots)
      latest_present_at = snapshots.find { _1.presence_state == "present" }&.observed_at

      {
        lifecycle_state: state,
        last_confirmed_present_at: [ posting.last_confirmed_present_at, latest_present_at ].compact.max,
        missing_since: ACTIVE_LIFECYCLE_STATES.include?(state) ? nil : current_absence_started_at(snapshots)
      }
    end

    def projected_state(snapshots)
      latest = snapshots.first
      return "present" if newer_unrepresented_presence?(latest)

      if latest.presence_state == "present"
        previous = snapshots.second
        return "reappeared" if previous && ABSENCE_PRESENCE_STATES.include?(previous.presence_state)

        return "present"
      end

      current_absence = snapshots.take_while { ABSENCE_PRESENCE_STATES.include?(_1.presence_state) }
      return "closed" if current_absence.any? { _1.presence_state == "explicit_closed" }

      "missing"
    end

    def newer_unrepresented_presence?(latest_snapshot)
      posting.last_confirmed_present_at.present? && posting.last_confirmed_present_at > latest_snapshot.observed_at
    end

    def current_absence_started_at(snapshots)
      snapshots
        .take_while { ABSENCE_PRESENCE_STATES.include?(_1.presence_state) }
        .map(&:observed_at)
        .min
    end

    def reconcile_opening
      return unless posting.job_opening_id

      ReconcileOpeningLifecycle.call(opening_id: posting.job_opening_id)
    end

    def find_record(klass, value, typed_prefix)
      value.to_s.start_with?(typed_prefix) ? klass.find_by_typed_id!(value) : klass.find(value)
    end
  end
end
