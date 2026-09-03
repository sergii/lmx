# frozen_string_literal: true

module Delivery
  module Telegram
    class Publisher
      MESSAGE_TYPE = "delivery.telegram.job_posting"

      class << self
        def call(client:, limit: 50, now: Time.current)
          messages = Platform::Reliability::OutboxClaims.claim(
            message_types: [ MESSAGE_TYPE ],
            limit:,
            at: now
          )

          messages.each do |message|
            publish(message, client:, now:)
          end

          messages.size
        end

        private

        def publish(message, client:, now:)
          client.send_message(text: Formatter.call(message.fetch(:payload)))
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
