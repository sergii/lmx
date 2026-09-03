# frozen_string_literal: true

require "nokogiri"
require "time"
require "uri"

module Acquisition
  module Djinni
    class FeedParser
      Vacancy = Data.define(
        :external_id,
        :url,
        :title,
        :summary,
        :published_at
      )

      def parse(xml, base_url:)
        document = Nokogiri::XML(xml.to_s) { _1.strict.nonet }
        document.xpath("/rss/channel/item").filter_map { parse_item(_1, base_url:) }
      end

      private

      def parse_item(item, base_url:)
        link = text(item.at_xpath("./link"))
        return if link.blank?

        url = absolute_url(base_url, link)
        external_id = vacancy_id(url)
        return unless external_id

        Vacancy.new(
          external_id:,
          url:,
          title: text(item.at_xpath("./title")),
          summary: description_text(item.at_xpath("./description")),
          published_at: parse_time(text(item.at_xpath("./pubDate")))
        )
      end

      def vacancy_id(url)
        url[%r{/jobs/(\d+)(?:-|/|\z)}, 1]
      end

      def absolute_url(base_url, href)
        URI.join(base_url, href).to_s
      rescue URI::InvalidURIError
        href
      end

      def description_text(node)
        value = node&.text.to_s
        return if value.blank?

        Nokogiri::HTML.fragment(value).text.gsub(/\s+/, " ").strip.presence
      end

      def parse_time(value)
        Time.rfc2822(value).in_time_zone if value.present?
      rescue ArgumentError
        nil
      end

      def text(node)
        node&.text.to_s.gsub(/\s+/, " ").strip.presence
      end
    end
  end
end
