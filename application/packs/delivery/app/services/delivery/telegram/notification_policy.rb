# frozen_string_literal: true

module Delivery
  module Telegram
    class NotificationPolicy
      DEFAULT_ACTION_PRIORITY_THRESHOLD = 80.0

      class << self
        def deliver?(payload, profile: {}, action_priority_threshold: nil)
          new(
            payload:,
            profile:,
            action_priority_threshold:
          ).deliver?
        end
      end

      def initialize(payload:, profile:, action_priority_threshold:)
        @payload = payload
        @profile = profile || {}
        @action_priority_threshold = action_priority_threshold
      end

      def deliver?
        return opportunity_assessment? if payload["notification_kind"] == "opportunity_assessed"

        posting_notification?
      end

      private

      attr_reader :payload, :profile, :action_priority_threshold

      def opportunity_assessment?
        return false unless preferred?("high_action_priority")

        priority = numeric(payload["action_priority"])
        return false unless priority

        priority >= threshold
      end

      def posting_notification?
        return true if preferences.empty?

        preference_keys.any? { preferred?(_1) }
      end

      def preference_keys
        posting_change_kinds.filter_map do |kind|
          case kind
          when "new_posting"
            "new_local_fast_opportunity" if local_fast_source?
          when "material_posting_change"
            "material_posting_change"
          when "compensation_change"
            "compensation_change"
          when "repost_or_reopen"
            "repost_or_reopen"
          end
        end.uniq
      end

      def posting_change_kinds
        kinds = Array(payload["change_kinds"]).filter_map { _1.to_s.strip.presence }
        return kinds if kinds.any?

        case payload["event_type"]
        when "JobPostingDiscovered"
          [ "new_posting" ]
        when "JobPostingUpdated"
          [ "material_posting_change" ]
        else
          []
        end
      end

      def local_fast_source?
        source_key = payload["source_key"].to_s
        profile.dig("source_priorities", source_key, "lane").to_s == "local_fast"
      end

      def preferred?(key)
        preferences.empty? || preferences.include?(key)
      end

      def preferences
        @preferences ||= Array(notification.fetch("prefer_near_real_time_for", nil))
          .filter_map { _1.to_s.strip.presence }
          .freeze
      end

      def notification
        @notification ||= profile.fetch("notification", {}) || {}
      end

      def threshold
        explicit = numeric(action_priority_threshold)
        return explicit if explicit

        numeric(notification["action_priority_threshold"]) || DEFAULT_ACTION_PRIORITY_THRESHOLD
      end

      def numeric(value)
        Float(value, exception: false)
      end
    end
  end
end
