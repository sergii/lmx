# frozen_string_literal: true

module Delivery
  class TelegramHealth
    class << self
      def check(env: ENV, client_class: Telegram::Client)
        config = RuntimeRequirements.fetch!("TELEGRAM_BOT_TOKEN", "TELEGRAM_CHAT_ID", env:)
        client_class.new(
          token: config.fetch("TELEGRAM_BOT_TOKEN"),
          chat_id: config.fetch("TELEGRAM_CHAT_ID")
        ).probe!

        { reachable: true }.freeze
      end
    end
  end
end
