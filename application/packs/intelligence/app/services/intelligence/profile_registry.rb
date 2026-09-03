# frozen_string_literal: true

module Intelligence
  class ProfileRegistry
    class << self
      def source_priority(source_id)
        priorities = profile.fetch("source_priorities")
        priority = priorities[source_id.to_s]
        return priority if priority

        raise KeyError, "Unknown source priority: #{source_id}"
      end

      def ranking
        profile.fetch("ranking")
      end

      def policies
        profile.fetch("policies")
      end

      def notification
        profile.fetch("notification", {}.freeze)
      end

      private

      def profile
        Lmx::Configuration.default_profile
      end
    end
  end
end
