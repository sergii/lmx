# frozen_string_literal: true

module Delivery
  module Telegram
    class NotificationPolicy
      DEFAULT_ACTION_PRIORITY_THRESHOLD = 80.0

      class << self
        def deliver?(payload, action_priority_threshold: DEFAULT_ACTION_PRIORITY_THRESHOLD)
          new(payload:, action_priority_threshold:).deliver?
        end
      end

      def initialize(payload:, action_priority_threshold:)
        @payload = payload
        @action_priority_threshold = action_priority_threshold
      end

      def deliver?
        return true unless payload["notification_kind"] == "opportunity_assessed"

        priority = numeric(payload["action_priority"])
        return false unless priority

        priority >= threshold
      end

      private

      attr_reader :payload, :action_priority_threshold

      def threshold
        numeric(action_priority_threshold) || DEFAULT_ACTION_PRIORITY_THRESHOLD
      end

      def numeric(value)
        Float(value, exception: false)
      end
    end
  end
end
