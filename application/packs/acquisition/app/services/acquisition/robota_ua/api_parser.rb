# frozen_string_literal: true

require "json"
require "nokogiri"
require "uri"

module Acquisition
  module RobotaUa
    class ApiParser
      Vacancy = Data.define(
        :external_id,
        :url,
        :title,
        :company_name,
        :location_text,
        :summary,
        :published_at
      )

      def parse(json, base_url:)
        payload = JSON.parse(json.to_s)
        documents = payload.fetch("documents")
        raise TypeError, "Robota.ua documents must be an array" unless documents.is_a?(Array)

        documents.filter_map { parse_document(_1, base_url:) }
      end

      private

      def parse_document(document, base_url:)
        raise TypeError, "Robota.ua vacancy document must be an object" unless document.is_a?(Hash)

        id = document["id"].to_s.strip.presence
        notebook_id = document["notebookId"].to_s.strip.presence
        return unless id && notebook_id

        Vacancy.new(
          external_id: id,
          url: vacancy_url(base_url, notebook_id:, id:),
          title: clean_text(document["name"]),
          company_name: clean_text(document["companyName"]),
          location_text: clean_text(document["cityName"]),
          summary: html_text(document["shortDescription"]),
          published_at: parse_time(document["date"])
        )
      end

      def vacancy_url(base_url, notebook_id:, id:)
        URI.join(base_url, "company#{notebook_id}/vacancy#{id}").to_s
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
