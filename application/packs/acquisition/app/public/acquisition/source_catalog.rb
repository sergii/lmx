# frozen_string_literal: true

module Acquisition
  class SourceCatalog
    class << self
      def all
        SourceRegistry.source_ids.map { snapshot(SourceRegistry.fetch(_1)) }.freeze
      end

      def fetch(source_id)
        snapshot(SourceRegistry.fetch(source_id))
      end

      def active
        all.select { _1.fetch(:enabled) && _1.fetch(:lifecycle_status) == "active" }.freeze
      end

      def active_source_ids
        active.map { _1.fetch(:id) }.freeze
      end

      private

      def snapshot(source)
        deep_freeze(
          {
            id: source.fetch("id"),
            name: source.fetch("name"),
            kind: source.fetch("kind"),
            market: source["market"],
            enabled: source.fetch("enabled"),
            coverage: source.fetch("coverage").deep_dup,
            lifecycle_status: source.fetch("lifecycle").fetch("status"),
            lifecycle_reason: source.dig("lifecycle", "reason"),
            primary_strategy: SourceRegistry.primary_strategy(source.fetch("id"))&.deep_dup
          }.compact
        )
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
