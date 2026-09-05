# frozen_string_literal: true

module Delivery
  module Telegram
    module Formatter
      module_function

      def call(payload, public_base_url: nil)
        return format_opportunity(payload) if payload["notification_kind"] == "opportunity_assessed"

        format_posting(payload, public_base_url:)
      end

      def format_posting(payload, public_base_url:)
        kinds = posting_change_kinds(payload)
        title = payload.fetch("title")
        source = payload.fetch("source_key").to_s.upcase

        lines = [ "#{posting_marker(kinds)} #{title}" ]
        label = posting_change_label(kinds)
        lines << label if label
        lines << source
        lines << posting_url(payload, public_base_url:)
        lines.compact.join("\n")
      end
      private_class_method :format_posting

      def posting_marker(kinds)
        return "♻️" if kinds.include?("repost_or_reopen")
        return "💰" if kinds.include?("compensation_change")
        return "🆕" if kinds.include?("new_posting")

        "✏️"
      end
      private_class_method :posting_marker

      def posting_change_label(kinds)
        return "Reopened or reposted" if kinds.include?("repost_or_reopen")
        return "Compensation changed" if kinds.include?("compensation_change")
        return if kinds.include?("new_posting")

        "Posting changed" if kinds.include?("material_posting_change")
      end
      private_class_method :posting_change_label

      def posting_change_kinds(payload)
        kinds = Array(payload["change_kinds"]).filter_map { _1.to_s.strip.presence }
        return kinds if kinds.any?

        case payload["event_type"]
        when "JobPostingDiscovered"
          [ "new_posting" ]
        else
          [ "material_posting_change" ]
        end
      end
      private_class_method :posting_change_kinds

      def posting_url(payload, public_base_url:)
        opening_id = payload["job_opening_id"].to_s.strip.presence
        base_url = public_base_url.to_s.strip.sub(%r{/+\z}, "").presence
        return "#{base_url}/openings/#{opening_id}" if opening_id && base_url

        payload["canonical_url"].presence || payload["application_url"].presence
      end
      private_class_method :posting_url

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
