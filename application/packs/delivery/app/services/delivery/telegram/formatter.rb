# frozen_string_literal: true

module Delivery
  module Telegram
    module Formatter
      module_function

      def call(payload)
        event_type = payload.fetch("event_type")
        marker = event_type == "JobPostingDiscovered" ? "🆕" : "✏️"
        title = payload.fetch("title")
        source = payload.fetch("source_key").to_s.upcase
        url = payload["canonical_url"].presence || payload["application_url"].presence

        [ "#{marker} #{title}", source, url ].compact.join("\n")
      end
    end
  end
end
