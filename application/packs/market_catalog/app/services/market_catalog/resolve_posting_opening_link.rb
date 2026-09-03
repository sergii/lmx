# frozen_string_literal: true

module MarketCatalog
  class ResolvePostingOpeningLink
    class << self
      def call(posting_id:, opening_id:, confidence:, evidence:, resolver_key:, resolver_version:, decided_at: Time.current,
        metadata: {})
        new(
          posting_id:,
          opening_id:,
          confidence:,
          evidence:,
          resolver_key:,
          resolver_version:,
          decided_at:,
          metadata:
        ).call
      end
    end

    def initialize(posting_id:, opening_id:, confidence:, evidence:, resolver_key:, resolver_version:, decided_at:, metadata:)
      @posting = find_record(JobPosting, posting_id, "posting_")
      @opening = opening_id.present? ? find_record(JobOpening, opening_id, "opening_") : nil
      @confidence = confidence
      @evidence = evidence || []
      @resolver_key = resolver_key.to_s.strip.downcase
      @resolver_version = resolver_version.to_s.strip.downcase
      @decided_at = decided_at.respond_to?(:in_time_zone) ? decided_at.in_time_zone : Time.zone.parse(decided_at.to_s)
      @metadata = metadata || {}
    end

    def call
      affected_opening_ids = []

      decision = JobPosting.transaction do
        posting.lock!
        previous_opening = posting.job_opening
        next if previous_opening == opening

        affected_opening_ids = [ previous_opening&.id, opening&.id ].compact.uniq
        decision_type = transition_type(previous_opening, opening)
        posting.update!(job_opening: opening)

        ResolutionDecision.create!(
          decision_type:,
          job_posting: posting,
          from_job_opening: previous_opening,
          to_job_opening: opening,
          confidence:,
          evidence:,
          resolver_key:,
          resolver_version:,
          decided_at:,
          metadata:
        )
      end

      affected_opening_ids.each { ReconcileOpeningLifecycle.call(opening_id: _1) }
      decision
    end

    private

    attr_reader :posting, :opening, :confidence, :evidence, :resolver_key, :resolver_version, :decided_at, :metadata

    def transition_type(previous_opening, next_opening)
      return "link_posting" if previous_opening.nil?
      return "unlink_posting" if next_opening.nil?

      "relink_posting"
    end

    def find_record(klass, value, typed_prefix)
      value.to_s.start_with?(typed_prefix) ? klass.find_by_typed_id!(value) : klass.find(value)
    end
  end
end
