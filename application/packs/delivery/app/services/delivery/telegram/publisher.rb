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
          profile: {},
          action_priority_threshold: nil,
          public_base_url: nil
        )
          messages = Platform::Reliability::OutboxClaims.claim(
            message_types: MESSAGE_TYPES,
            limit:,
            at: now
          )

          messages.each do |message|
            publish(
              message,
              client:,
              now:,
              profile:,
              action_priority_threshold:,
              public_base_url:
            )
          end

          messages.size
        end

        private

        def publish(message, client:, now:, profile:, action_priority_threshold:, public_base_url:)
          payload = message.fetch(:payload)
          if NotificationPolicy.deliver?(payload, profile:, action_priority_threshold:)
            client.send_message(text: Formatter.call(payload, public_base_url:))
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
