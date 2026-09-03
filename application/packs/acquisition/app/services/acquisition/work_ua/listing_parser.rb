# frozen_string_literal: true

require "nokogiri"
require "uri"

module Acquisition
  module WorkUa
    class ListingParser
      Vacancy = Data.define(
        :external_id,
        :url,
        :title,
        :company_name,
        :location_text
      )

      def parse(html, base_url:)
        document = Nokogiri::HTML(html.to_s)
        document.css("div.job-link").filter_map { parse_card(_1, base_url:) }
      end

      private

      def parse_card(card, base_url:)
        link = card.at_css("h2 a[href]")
        href = link&.[]("href").to_s
        external_id = vacancy_id(href)
        return unless external_id

        Vacancy.new(
          external_id:,
          url: absolute_url(base_url, href),
          title: clean_text(link),
          company_name: clean_text(card.at_css("div.add-top-xs span.strong-600")),
          location_text: clean_text(card.at_css("span.text-default-700"))
        )
      end

      def vacancy_id(href)
        href[%r{/jobs/(\d+)(?:/|\z)}, 1]
      end

      def absolute_url(base_url, href)
        URI.join(base_url, href).to_s
      rescue URI::InvalidURIError
        href
      end

      def clean_text(node)
        node&.text.to_s.gsub(/\s+/, " ").strip.presence
      end
    end
  end
end
