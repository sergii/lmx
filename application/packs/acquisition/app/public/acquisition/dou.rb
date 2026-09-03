# frozen_string_literal: true

module Acquisition
  module Dou
    SOURCE_KEY = "dou"
    COLLECTOR_VERSION = "dou-collector-v2"
    ADAPTER_VERSIONS = {
      "rss" => "dou-rss-v1",
      "http_html" => "dou-http-html-v1"
    }.freeze
    PARSER_VERSIONS = {
      "rss" => "dou-rss-v1",
      "http_html" => "dou-listing-v1"
    }.freeze

    Result = Data.define(
      :source_run_id,
      :status,
      :strategy,
      :request_url,
      :fetched_count,
      :discovered_count,
      :observed_count,
      :raw_payload_ids,
      :ingestion_record_ids,
      :observation_ids
    )

    class RunFailed < StandardError; end

    class << self
      def collect(
        search: nil,
        strategy: nil,
        run_key: nil,
        started_at: Time.current,
        http_client: nil,
        parser: nil,
        clock: -> { Time.current }
      )
        Telemetry.collect(
          source_key: SOURCE_KEY,
          search:,
          requested_strategy: strategy,
          collector_version: COLLECTOR_VERSION,
          adapter_versions: ADAPTER_VERSIONS,
          parser_versions: PARSER_VERSIONS,
          http_client: http_client || HttpClient.new,
          parser:,
          parser_factory: method(:parser_for_strategy)
        ) do |instrumented_http_client, instrumented_parser|
          Collector.call(
            search:,
            strategy:,
            run_key:,
            started_at:,
            http_client: instrumented_http_client,
            parser: instrumented_parser,
            clock:
          )
        end
      end

      private

      def parser_for_strategy(strategy_type)
        case strategy_type
        when "rss" then FeedParser.new
        when "http_html" then ListingParser.new
        end
      end
    end
  end
end
