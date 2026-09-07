# frozen_string_literal: true

require "nokogiri"

module Acquisition
  module Djinni
    class ListingEnrichmentParser
      Enrichment = Data.define(
        :external_id,
        :company_name,
        :location_text,
        :compensation_text
      )

      CARD_SELECTOR = ".list-jobs__item"
      TITLE_LINK_SELECTORS = [
        ".job-list-item__title > a",
        ".list-jobs__title a"
      ].freeze
      COMPANY_SELECTORS = [
        "a.mr-2",
        ".list-jobs__details__info a:not(.link-muted)",
        ".list-jobs__details__info a"
      ].freeze
      LOCATION_SELECTORS = [
        "span.location-text",
        ".location-text"
      ].freeze
      COMPENSATION_SELECTORS = [
        "span.public-salary-item",
        ".public-salary-item"
      ].freeze

      def parse(html)
        document = Nokogiri::HTML(html.to_s)
        document.css(CARD_SELECTOR).filter_map { parse_card(_1) }
      end

      private

      def parse_card(card)
        href = first_attribute(card, TITLE_LINK_SELECTORS, "href")
        external_id = vacancy_id(href)
        return unless external_id

        Enrichment.new(
          external_id:,
          company_name: first_text(card, COMPANY_SELECTORS),
          location_text: first_text(card, LOCATION_SELECTORS),
          compensation_text: first_text(card, COMPENSATION_SELECTORS)
        )
      end

      def first_text(node, selectors)
        selectors.each do |selector|
          value = text(node.at_css(selector))
          return value if value.present?
        end

        nil
      end

      def first_attribute(node, selectors, attribute)
        selectors.each do |selector|
          value = node.at_css(selector)&.[](attribute).to_s.strip.presence
          return value if value
        end

        nil
      end

      def vacancy_id(url)
        url.to_s[%r{/jobs/(\d+)(?:-|/|\z)}, 1]
      end

      def text(node)
        node&.text.to_s.gsub(/\s+/, " ").strip.presence
      end
    end
  end
end
