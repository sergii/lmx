# frozen_string_literal: true

module Delivery
  module Telegram
    class Publisher
      POSTING_MESSAGE_TYPE = "delivery.telegram.job_posting"
      OPPORTUNITY_MESSAGE_TYPE = "delivery.telegram.opportunity"
      MESSAGE_TYPES = [ POSTING_MESSAGE_TYPE, OPPORTUNITY_MESSAGE_TYPE ].freeze

      NOTIFY_SPAN = "lmx.delivery.notify"
      DELIVERY_TOTAL = "lmx.notification.delivery.total"

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
          attributes = telemetry_attributes(message, payload)

          Platform::Telemetry.in_span(NOTIFY_SPAN, attributes:) do |span|
            delivered = NotificationPolicy.deliver?(payload, profile:, action_priority_threshold:)
            client.send_message(text: Formatter.call(payload, public_base_url:)) if delivered

            outcome = delivered ? "sent" : "suppressed"
            Platform::Reliability::Api.mark_outbox_published(
              message_id: message.fetch(:id),
              published_at: now
            )
            Platform::Telemetry.add_attributes(span, "lmx.delivery.outcome" => outcome)
            record_delivery(outcome, attributes)
          end
        rescue StandardError => error
          record_delivery("failure", attributes || {})
          Platform::Reliability::Api.mark_outbox_failed(
            message_id: message.fetch(:id),
            error: { "class" => error.class.name, "message" => error.message },
            retry_at: now + 1.minute
          )
        end

        def telemetry_attributes(message, payload)
          {
            "messaging.destination.name" => "telegram",
            "lmx.message.type" => message[:message_type],
            "lmx.source.id" => payload["source_key"],
            "lmx.notification.kind" => payload["notification_kind"],
            "lmx.correlation.id" => message[:correlation_id]
          }.compact
        end

        def record_delivery(outcome, attributes)
          Platform::Telemetry.increment(
            DELIVERY_TOTAL,
            description: "Telegram notification delivery outcomes",
            attributes: attributes.merge("lmx.delivery.outcome" => outcome)
          )
        end
      end
    end
  end
end
