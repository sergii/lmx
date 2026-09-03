# frozen_string_literal: true

require "nokogiri"
require "uri"

module Acquisition
  module Dou
    class ListingParser
      Vacancy = Data.define(
        :external_id,
        :url,
        :title,
        :company_name,
        :location_text,
        :summary,
        :listed_at_text,
        :published_at
      )

      def parse(html, base_url:)
        document = Nokogiri::HTML(html.to_s)
        document.css(".l-vacancy").filter_map { parse_card(_1, base_url:) }
      end

      private

      def parse_card(card, base_url:)
        title_link = card.at_css("a.vt[href], .title a[href*='/vacancies/']")
        return unless title_link

        href = title_link["href"].to_s.strip
        external_id = vacancy_id(href)
        return unless external_id

        Vacancy.new(
          external_id:,
          url: absolute_url(base_url, href),
          title: text(title_link),
          company_name: text(card.at_css(".company")),
          location_text: text(card.at_css(".cities, .location")),
          summary: text(card.at_css(".sh-info, .text")),
          listed_at_text: text(card.at_css(".date")),
          published_at: nil
        )
      end

      def vacancy_id(href)
        href[%r{/vacancies/(\d+)/?}, 1]
      end

      def absolute_url(base_url, href)
        URI.join(base_url, href).to_s
      rescue URI::InvalidURIError
        href
      end

      def text(node)
        node&.text.to_s.gsub(/\s+/, " ").strip.presence
      end
    end
  end
end
