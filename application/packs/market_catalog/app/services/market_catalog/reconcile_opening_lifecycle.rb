# frozen_string_literal: true

module MarketCatalog
  class ReconcileOpeningLifecycle
    ACTIVE_POSTING_STATES = %w[present reappeared].freeze

    class << self
      def call(opening_id:)
        new(opening_id:).call
      end
    end

    def initialize(opening_id:)
      @opening = find_record(JobOpening, opening_id, "opening_")
    end

    def call
      opening.with_lock do
        postings = opening.job_postings.to_a
        next if postings.empty?

        opening.update!(projected_attributes(postings))
      end

      opening
    end

    private

    attr_reader :opening

    def projected_attributes(postings)
      state = projected_state(postings)
      latest_present_at = postings.filter_map(&:last_confirmed_present_at).max

      {
        lifecycle_state: state,
        last_seen_at: [ opening.last_seen_at, latest_present_at ].compact.max,
        closed_at: state == "closed" ? projected_closed_at(postings) : nil
      }
    end

    def projected_state(postings)
      states = postings.map(&:lifecycle_state)

      if states.any? { ACTIVE_POSTING_STATES.include?(_1) }
        return "reopened" if states.include?("reappeared")

        return "open"
      end

      return "closed" if states.all? { _1 == "closed" }
      return "probably_closed" if states.include?("probably_closed")

      "missing"
    end

    def projected_closed_at(postings)
      postings.filter_map { explicit_closure_observed_at(_1) }.max || opening.closed_at
    end

    def explicit_closure_observed_at(posting)
      relation = posting.snapshots.where(presence_state: "explicit_closed")
      relation = relation.where("observed_at >= ?", posting.missing_since) if posting.missing_since
      relation.maximum(:observed_at)
    end

    def find_record(klass, value, typed_prefix)
      value.to_s.start_with?(typed_prefix) ? klass.find_by_typed_id!(value) : klass.find(value)
    end
  end
end
