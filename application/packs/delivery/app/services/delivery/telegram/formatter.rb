# frozen_string_literal: true

module Delivery
  module Telegram
    module Formatter
      module_function

      def call(payload)
        return format_opportunity(payload) if payload["notification_kind"] == "opportunity_assessed"

        format_posting(payload)
      end

      def format_posting(payload)
        event_type = payload.fetch("event_type")
        marker = event_type == "JobPostingDiscovered" ? "🆕" : "✏️"
        title = payload.fetch("title")
        source = payload.fetch("source_key").to_s.upcase
        url = payload["canonical_url"].presence || payload["application_url"].presence

        [ "#{marker} #{title}", source, url ].compact.join("\n")
      end
      private_class_method :format_posting

      def format_opportunity(payload)
        title = payload.fetch("title")
        company = payload["company_name"].to_s.presence
        priority = numeric(payload["action_priority"])
        opportunity = numeric(payload["opportunity_score"])
        heading = [ title, company ].compact.join(" @ ")
        source = payload["source_key"].to_s.upcase.presence
        url = payload["url"].to_s.presence

        lines = [ "#{opportunity_marker(priority)} #{heading}" ]
        score_line = score_line(priority:, opportunity:)
        lines << score_line if score_line
        lines << payload["recommendation"].to_s.presence
        lines << list_line("Strengths", payload["strengths"], limit: 2)
        lines << list_line("Gaps", payload["gaps"], limit: 1)
        lines << list_line("Risks", payload["risks"], limit: 1)
        lines << list_line("Interview", payload["interview_angles"], limit: 1)
        lines << source
        lines << url
        lines.compact.join("\n")
      end
      private_class_method :format_opportunity

      def opportunity_marker(priority)
        return "🔥" if priority && priority >= 90
        return "⭐" if priority && priority >= 80

        "🧭"
      end
      private_class_method :opportunity_marker

      def score_line(priority:, opportunity:)
        values = []
        values << "Priority #{format_score(priority)}" if priority
        values << "Opportunity #{format_score(opportunity)}" if opportunity
        values.join(" · ").presence
      end
      private_class_method :score_line

      def list_line(label, values, limit:)
        items = Array(values).filter_map { _1.to_s.strip.presence }.first(limit)
        return if items.empty?

        "#{label}: #{items.join('; ')}"
      end
      private_class_method :list_line

      def format_score(value)
        value.round(1).to_s.sub(/\.0\z/, "")
      end
      private_class_method :format_score

      def numeric(value)
        Float(value, exception: false)
      end
      private_class_method :numeric
    end
  end
end
