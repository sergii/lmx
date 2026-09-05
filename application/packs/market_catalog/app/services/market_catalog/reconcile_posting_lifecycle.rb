# frozen_string_literal: true

module MarketCatalog
  class ReconcilePostingLifecycle
    DEFINITIVE_PRESENCE_STATES = %w[present missing explicit_closed].freeze
    ABSENCE_PRESENCE_STATES = %w[missing explicit_closed].freeze
    ACTIVE_LIFECYCLE_STATES = %w[present reappeared].freeze
    PROJECTION_METADATA_KEY = "lifecycle_projection"
    RECONCILE_SPAN = "lmx.market_catalog.reconcile"

    class << self
      def call(posting_id:, policy: PostingLifecyclePolicy.from_env)
        new(posting_id:, policy:).call
      end
    end

    def initialize(posting_id:, policy:)
      @posting = find_record(JobPosting, posting_id, "posting_")
      @policy = policy
    end

    def call
      Platform::Telemetry.in_span(
        RECONCILE_SPAN,
        attributes: {
          "lmx.posting.id" => posting.typed_id,
          "lmx.source.id" => posting.source_key,
          "lmx.lifecycle.policy_version" => policy.version
        }
      ) do |span|
        previous_state = posting.lifecycle_state
        reconcile
        Platform::Telemetry.add_attributes(
          span,
          "lmx.lifecycle.previous_state" => previous_state,
          "lmx.lifecycle.current_state" => posting.lifecycle_state,
          "lmx.opening.id" => posting.job_opening&.typed_id
        )
        posting
      end
    end

    private

    attr_reader :posting, :policy

    def reconcile
      reopen_event_at = nil

      posting.with_lock do
        snapshots = definitive_snapshots
        next if snapshots.empty?

        previous_state = posting.lifecycle_state
        posting.update!(projected_attributes(snapshots))

        if previous_state != posting.lifecycle_state && posting.lifecycle_state == "reappeared"
          reopen_event_at = snapshots.first.observed_at
        end
      end

      reconcile_opening
      emit_reopen_event(reopen_event_at) if reopen_event_at
    end

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
        missing_since: ACTIVE_LIFECYCLE_STATES.include?(state) ? nil : current_absence_started_at(snapshots),
        metadata: projection_metadata(snapshots, state:)
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

      current_absence = current_absence_snapshots(snapshots)
      return "closed" if current_absence.any? { _1.presence_state == "explicit_closed" }

      policy.state_for_missing_count(current_absence.count)
    end

    def projection_metadata(snapshots, state:)
      current_absence = current_absence_snapshots(snapshots)
      consecutive_missing = if ACTIVE_LIFECYCLE_STATES.include?(state)
        0
      else
        current_absence.count { _1.presence_state == "missing" }
      end

      posting.metadata.deep_dup.merge(
        PROJECTION_METADATA_KEY => policy.snapshot.merge(
          "consecutive_missing_observations" => consecutive_missing,
          "latest_evidence_at" => snapshots.first.observed_at.iso8601(6)
        )
      )
    end

    def newer_unrepresented_presence?(latest_snapshot)
      posting.last_confirmed_present_at.present? && posting.last_confirmed_present_at > latest_snapshot.observed_at
    end

    def current_absence_snapshots(snapshots)
      snapshots.take_while { ABSENCE_PRESENCE_STATES.include?(_1.presence_state) }
    end

    def current_absence_started_at(snapshots)
      current_absence_snapshots(snapshots).map(&:observed_at).min
    end

    def reconcile_opening
      return unless posting.job_opening_id

      ReconcileOpeningLifecycle.call(opening_id: posting.job_opening_id)
    end

    def emit_reopen_event(occurred_at)
      EmitPostingEvent.call(
        posting:,
        event_type: "JobPostingLifecycleChanged",
        occurred_at:,
        change_kinds: [ "repost_or_reopen" ]
      )
    end

    def find_record(klass, value, typed_prefix)
      value.to_s.start_with?(typed_prefix) ? klass.find_by_typed_id!(value) : klass.find(value)
    end
  end
end
