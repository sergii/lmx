# frozen_string_literal: true

require "json"
require "nokogiri"
require "uri"

module Acquisition
  module RemoteOk
    class ApiParser
      Vacancy = Data.define(
        :external_id,
        :url,
        :apply_url,
        :title,
        :company_name,
        :location_text,
        :summary,
        :published_at,
        :tags,
        :salary_min,
        :salary_max
      )

      def parse(json, base_url:)
        payload = JSON.parse(json.to_s)
        raise TypeError, "Remote OK API payload must be an array" unless payload.is_a?(Array)

        payload.filter_map { parse_document(_1, base_url:) }
      end

      private

      def parse_document(document, base_url:)
        raise TypeError, "Remote OK API record must be an object" unless document.is_a?(Hash)
        return if document.key?("legal") && document["id"].blank?

        id = document["id"].to_s.strip.presence
        url = absolute_url(base_url, document["url"])
        return unless id && url

        Vacancy.new(
          external_id: id,
          url:,
          apply_url: absolute_url(base_url, document["apply_url"]),
          title: clean_text(document["position"]),
          company_name: clean_text(document["company"]),
          location_text: clean_text(document["location"]),
          summary: html_text(document["description"]),
          published_at: published_at(document),
          tags: normalize_tags(document["tags"]),
          salary_min: numeric(document["salary_min"]),
          salary_max: numeric(document["salary_max"])
        )
      end

      def published_at(document)
        parsed = parse_time(document["date"])
        return parsed if parsed

        epoch = document["epoch"]
        Time.zone.at(epoch.to_i) if epoch.to_i.positive?
      end

      def normalize_tags(value)
        return [] unless value.is_a?(Array)

        value.filter_map { clean_text(_1) }.uniq.freeze
      end

      def numeric(value)
        value if value.is_a?(Numeric)
      end

      def absolute_url(base_url, value)
        value = value.to_s.strip.presence
        return unless value

        URI.join(base_url, value).to_s
      rescue URI::InvalidURIError
        value
      end

      def html_text(value)
        return if value.blank?

        Nokogiri::HTML.fragment(value.to_s).text.gsub(/\s+/, " ").strip.presence
      end

      def clean_text(value)
        value.to_s.gsub(/\s+/, " ").strip.presence
      end

      def parse_time(value)
        Time.zone.parse(value.to_s) if value.present?
      rescue ArgumentError
        nil
      end
    end
  end
end
