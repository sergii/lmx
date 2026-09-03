# frozen_string_literal: true

module Acquisition
  class SourceRegistry
    class << self
      def source_ids
        sources.map { _1.fetch("id") }.freeze
      end

      def fetch(source_id)
        source = sources.find { _1.fetch("id") == source_id.to_s }
        return source if source

        raise KeyError, "Unknown acquisition source: #{source_id}"
      end

      def acquisition_strategies(source_id)
        fetch(source_id).fetch("acquisition")
      end

      def primary_strategy(source_id)
        acquisition_strategies(source_id).find { _1.fetch("preference") == "primary" }
      end

      def enabled?(source_id)
        fetch(source_id).fetch("enabled")
      end

      private

      def sources
        Lmx::Configuration.sources.fetch("sources")
      end
    end
  end
end
