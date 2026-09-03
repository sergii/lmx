# frozen_string_literal: true

module Acquisition
  class QueryPolicy
    class << self
      def source_queries(source_id, profile: Lmx::Configuration.default_profile)
        queries = profile
          .fetch("acquisition", {})
          .fetch("source_queries", {})
          .fetch(source_id.to_s, [])

        queries.filter_map { _1.to_s.strip.presence }.uniq.freeze
      end
    end
  end
end
