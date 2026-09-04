# frozen_string_literal: true

module Delivery
  module Telegram
    class Publisher
      POSTING_MESSAGE_TYPE = "delivery.telegram.job_posting"
      OPPORTUNITY_MESSAGE_TYPE = "delivery.telegram.opportunity"
      MESSAGE_TYPES = [ POSTING_MESSAGE_TYPE, OPPORTUNITY_MESSAGE_TYPE ].freeze

      class << self
        def call(
          client:,
          limit: 50,
          now: Time.current,
          action_priority_threshold: NotificationPolicy::DEFAULT_ACTION_PRIORITY_THRESHOLD
        )
          messages = Platform::Reliability::OutboxClaims.claim(
            message_types: MESSAGE_TYPES,
            limit:,
            at: now
          )

          messages.each do |message|
            publish(message, client:, now:, action_priority_threshold:)
          end

          messages.size
        end

        private

        def publish(message, client:, now:, action_priority_threshold:)
          payload = message.fetch(:payload)
          if NotificationPolicy.deliver?(payload, action_priority_threshold:)
            client.send_message(text: Formatter.call(payload))
          end
          Platform::Reliability::Api.mark_outbox_published(
            message_id: message.fetch(:id),
            published_at: now
          )
        rescue StandardError => error
          Platform::Reliability::Api.mark_outbox_failed(
            message_id: message.fetch(:id),
            error: { "class" => error.class.name, "message" => error.message },
            retry_at: now + 1.minute
          )
        end
      end
    end
  end
end
