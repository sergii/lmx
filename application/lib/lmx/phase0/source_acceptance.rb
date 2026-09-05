# frozen_string_literal: true

module Lmx
  module Phase0
    class SourceAcceptance
      DEFAULT_SOURCES = %w[dou djinni work_ua robota_ua].freeze

      class << self
        def call(**)
          new.call(**)
        end
      end

      def initialize(
        source_catalog: Acquisition::SourceCatalog,
        source_health: Acquisition::SourceHealth,
        replay: Acquisition::Replay,
        runner: ->(source_key) { AcquisitionCollectionJob.new.perform(source_key) },
        clock: -> { Time.current }
      )
        @source_catalog = source_catalog
        @source_health = source_health
        @replay = replay
        @runner = runner
        @clock = clock
      end

      def call(source_keys: DEFAULT_SOURCES)
        sources = normalize_source_keys(source_keys)
        validate_sources!(sources)

        results = sources.map { accept_source(_1) }

        deep_freeze(
          status: results.all? { _1.fetch(:status) == "pass" } ? "pass" : "fail",
          checked_at: now.iso8601,
          sources: results
        )
      end

      private

      attr_reader :source_catalog, :source_health, :replay, :runner, :clock

      def accept_source(source_key)
        before = source_health.fetch(source_key)
        started_at = now
        run_results = normalize_run_results(runner.call(source_key))
        after = source_health.fetch(source_key)
        replay_result = replay.call(
          source_key:,
          from: started_at - 1.second,
          limit: 1,
          apply: false
        )

        failures = validation_failures(
          before:,
          after:,
          run_results:,
          replay_result:
        )

        deep_freeze(
          source_key:,
          status: failures.empty? ? "pass" : "fail",
          started_at: started_at.iso8601,
          run_ids: run_results.filter_map { _1[:source_run_id] },
          fetched_count: run_results.sum { _1[:fetched_count].to_i },
          discovered_count: run_results.sum { _1[:discovered_count].to_i },
          observed_count: run_results.sum { _1[:observed_count].to_i },
          latest_run_id: after[:latest_run_id],
          last_successful_at: normalize_time(after[:last_successful_at])&.iso8601,
          replayable_raw_payload: replay_result.fetch(:selected_raw_payloads).positive?,
          failures:
        )
      rescue StandardError => error
        deep_freeze(
          source_key:,
          status: "fail",
          started_at: started_at&.iso8601,
          error: {
            class: error.class.name,
            message: error.message
          }
        )
      end

      def validation_failures(before:, after:, run_results:, replay_result:)
        failures = []

        if run_results.empty?
          failures << "collector returned no run results"
        elsif run_results.any? { _1[:status].to_s != "succeeded" }
          failures << "one or more source runs did not succeed"
        end

        if after[:latest_run_id].blank? || after[:latest_run_id] == before[:latest_run_id]
          failures << "collector did not persist a new source run"
        end

        failures << "latest durable source run is not succeeded" unless after[:status].to_s == "succeeded"

        observed_count = run_results.sum { _1[:observed_count].to_i }
        failures << "live collection produced no source observations" unless observed_count.positive?

        unless replay_result.fetch(:selected_raw_payloads).positive?
          failures << "live collection did not leave replayable raw evidence"
        end

        failures.freeze
      end

      def normalize_run_results(value)
        Array(value).flatten.compact.map do |result|
          result.respond_to?(:to_h) ? result.to_h.symbolize_keys : result.symbolize_keys
        end
      end

      def normalize_source_keys(value)
        values = value.is_a?(String) ? value.split(",") : Array(value)
        values.map { _1.to_s.strip }.reject(&:blank?).uniq.freeze
      end

      def validate_sources!(sources)
        raise ArgumentError, "at least one source is required" if sources.empty?

        active = source_catalog.active_source_ids.map(&:to_s)
        unknown = sources - active
        return if unknown.empty?

        raise ArgumentError, "inactive or unknown acquisition source(s): #{unknown.join(', ')}"
      end

      def now
        normalize_time(clock.call) || raise(ArgumentError, "clock returned no time")
      end

      def normalize_time(value)
        return if value.blank?

        value.respond_to?(:in_time_zone) ? value.in_time_zone : Time.zone.parse(value.to_s)
      end

      def deep_freeze(value)
        case value
        when Hash
          value.each { |key, item| deep_freeze(key); deep_freeze(item) }
        when Array
          value.each { deep_freeze(_1) }
        end
        value.freeze
      end
    end
  end
end
