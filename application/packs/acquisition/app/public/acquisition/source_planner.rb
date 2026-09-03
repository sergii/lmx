# frozen_string_literal: true

module Acquisition
  class SourcePlanner
    MATCH_DIMENSIONS = %w[domains technologies roles industries work_modes].freeze

    class << self
      def plan(profile: Lmx::Configuration.default_profile)
        targets = profile.fetch("targets", {})

        SourceCatalog.all.map do |source|
          mismatches = mismatch_dimensions(source.fetch(:coverage), targets)
          reasons = selection_reasons(source, mismatches)

          deep_freeze(
            {
              source_id: source.fetch(:id),
              kind: source.fetch(:kind),
              lifecycle_status: source.fetch(:lifecycle_status),
              enabled: source.fetch(:enabled),
              selected: reasons.empty?,
              reasons:,
              mismatch_dimensions: mismatches,
              coverage: source.fetch(:coverage).deep_dup,
              primary_strategy: source[:primary_strategy]&.deep_dup,
              queries: QueryPolicy.source_queries(source.fetch(:id), profile:)
            }
          )
        end.freeze
      end

      def selected(profile: Lmx::Configuration.default_profile)
        plan(profile:).select { _1.fetch(:selected) }.freeze
      end

      private

      def selection_reasons(source, mismatches)
        reasons = []
        reasons << "disabled" unless source.fetch(:enabled)
        unless source.fetch(:lifecycle_status) == "active"
          reasons << "lifecycle_not_active:#{source.fetch(:lifecycle_status)}"
        end
        reasons.concat(mismatches.map { "coverage_mismatch:#{_1}" })
        reasons.freeze
      end

      def mismatch_dimensions(coverage, targets)
        MATCH_DIMENSIONS.filter do |dimension|
          source_values = normalized_values(coverage[dimension])
          target_values = normalized_values(targets[dimension])

          source_values.any? && target_values.any? && (source_values & target_values).empty?
        end.freeze
      end

      def normalized_values(values)
        Array(values).filter_map { _1.to_s.strip.presence }.uniq
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
