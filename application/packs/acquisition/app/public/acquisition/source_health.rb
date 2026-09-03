# frozen_string_literal: true

module Acquisition
  class SourceHealth
    class << self
      def all
        SourceCatalog.active_source_ids.map { fetch(_1) }.freeze
      end

      def fetch(source_key)
        source_key = source_key.to_s
        SourceRegistry.fetch(source_key)

        runs = SourceRun.where(source_key:)
        latest_run = runs.order(started_at: :desc, id: :desc).first
        last_successful_run = runs.where(status: "succeeded").order(started_at: :desc, id: :desc).first

        {
          source_key:,
          status: latest_run&.status || "never_run",
          latest_run_id: latest_run&.typed_id,
          last_attempted_at: latest_run&.started_at,
          last_successful_at: last_successful_run&.finished_at,
          transport: latest_run&.transport,
          duration_ms: duration_ms(latest_run),
          fetched_count: latest_run&.fetched_count,
          discovered_count: latest_run&.discovered_count,
          observed_count: latest_run&.observed_count,
          consecutive_failures: consecutive_failures(runs, last_successful_run),
          collector_version: latest_run&.collector_version,
          adapter_version: latest_run&.adapter_version,
          parser_version: latest_run&.parser_version,
          error: error_snapshot(latest_run)
        }.freeze
      end

      private

      def duration_ms(source_run)
        return unless source_run&.finished_at

        ((source_run.finished_at - source_run.started_at) * 1000).round
      end

      def consecutive_failures(runs, last_successful_run)
        failures = runs.where(status: "failed")
        failures = failures.where("started_at > ?", last_successful_run.started_at) if last_successful_run
        failures.count
      end

      def error_snapshot(source_run)
        return unless source_run&.status == "failed"

        {
          class: source_run.error_class,
          message: source_run.error_message,
          details: deep_freeze(source_run.error_details.deep_dup)
        }.freeze
      end

      def deep_freeze(value)
        case value
        when Hash
          value.each { |key, item| deep_freeze(key); deep_freeze(item) }.freeze
        when Array
          value.each { deep_freeze(_1) }.freeze
        else
          value.freeze
        end
      end
    end
  end
end
