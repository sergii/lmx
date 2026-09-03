# frozen_string_literal: true

require "digest"
require "uri"

module Acquisition
  module Dou
    class Collector
      TRANSPORT_MAP = {
        "rss" => "rss",
        "http_html" => "http_scrape"
      }.freeze
      REQUEST_PATHS = {
        "rss" => "/vacancies/feeds/",
        "http_html" => "/vacancies/"
      }.freeze
      EVIDENCE_KINDS = {
        "rss" => "job_posting_feed_entry",
        "http_html" => "job_posting_listing"
      }.freeze

      class UnsupportedSourceStrategy < StandardError; end

      class << self
        def call(search:, strategy:, run_key:, started_at:, http_client:, parser:, clock:)
          new(
            search:,
            strategy:,
            run_key:,
            started_at:,
            http_client:,
            parser:,
            clock:
          ).call
        end
      end

      def initialize(search:, strategy:, run_key:, started_at:, http_client:, parser:, clock:)
        @search = search.to_s.strip.presence
        @requested_strategy = strategy.to_s.strip.presence
        @run_key = run_key.to_s.strip.presence
        @started_at = normalize_time(started_at)
        @http_client = http_client
        @parser_override = parser
        @clock = clock
      end

      def call
        source_run = start_source_run
        return result_for(source_run) if source_run.successful?
        raise_previous_failure(source_run) if source_run.terminal?

        fetched_count = 0
        discovered_count = 0

        response = http_client.get(request_url)
        fetched_count = 1

        raw_payload = RecordRawPayload.call(
          source_run:,
          payload: response.body,
          captured_at: response.fetched_at,
          source_uri: response.url,
          content_type: response.content_type,
          encoding: response.body.encoding.name,
          provenance: {
            "http_status" => response.status,
            "request_url" => request_url,
            "strategy" => strategy_type
          }
        )

        ingestion = RecordIngestion.call(
          source_run:,
          raw_payload:,
          adapter_version: adapter_version,
          parser_version: parser_version,
          ingested_at: response.fetched_at,
          provenance: {
            "source" => SOURCE_KEY,
            "request_url" => request_url,
            "strategy" => strategy_type
          }
        )

        vacancies = parser.parse(response.body, base_url: source_base_url)
        discovered_count = vacancies.size

        observations = vacancies.map do |vacancy|
          RecordSourceObservation.call(
            source_run:,
            raw_payload:,
            observed_at: response.fetched_at,
            external_id: vacancy.external_id,
            original_url: vacancy.url,
            canonical_url: vacancy.url,
            source_published_at: vacancy.respond_to?(:published_at) ? vacancy.published_at : nil,
            presence_state: "present",
            adapter_version: adapter_version,
            parser_version: parser_version,
            payload: vacancy_payload(vacancy),
            ingestion_provenance: ingestion.provenance,
            metadata: {
              "evidence_kind" => EVIDENCE_KINDS.fetch(strategy_type),
              "extraction_method" => parser_version,
              "strategy" => strategy_type
            }
          )
        end

        SourceRuns.succeed(
          source_run:,
          finished_at: normalize_finish_time(response.fetched_at),
          fetched_count:,
          discovered_count:,
          observed_count: observations.size
        )

        result_for(source_run.reload)
      rescue StandardError => error
        fail_source_run(
          source_run,
          error,
          fetched_count:,
          discovered_count:
        ) if source_run&.status == "running"
        raise
      end

      private

      attr_reader :search, :requested_strategy, :run_key, :started_at, :http_client, :parser_override, :clock

      def start_source_run
        SourceRuns.start(
          source_key: SOURCE_KEY,
          transport: persisted_transport,
          started_at:,
          run_key: run_key || default_run_key,
          collector_version: COLLECTOR_VERSION,
          adapter_version: adapter_version,
          parser_version: parser_version,
          provenance: {
            "request_url" => request_url,
            "search" => search,
            "strategy" => strategy_type
          }
        )
      end

      def selected_strategy
        @selected_strategy ||= begin
          unless SourceRegistry.enabled?(SOURCE_KEY)
            raise UnsupportedSourceStrategy, "DOU acquisition source is disabled"
          end

          strategies = SourceRegistry.acquisition_strategies(SOURCE_KEY)
          selected = if requested_strategy
            strategies.find { _1.fetch("type") == requested_strategy }
          else
            SourceRegistry.primary_strategy(SOURCE_KEY)
          end

          unless selected
            raise UnsupportedSourceStrategy, "DOU acquisition strategy #{requested_strategy.inspect} is not configured"
          end
          if selected.fetch("status") == "disabled"
            raise UnsupportedSourceStrategy, "DOU acquisition strategy #{selected.fetch('type').inspect} is disabled"
          end

          selected
        end
      end

      def strategy_type
        @strategy_type ||= selected_strategy.fetch("type")
      end

      def persisted_transport
        TRANSPORT_MAP.fetch(strategy_type) do
          raise UnsupportedSourceStrategy, "unsupported DOU acquisition strategy #{strategy_type.inspect}"
        end
      end

      def adapter_version
        ADAPTER_VERSIONS.fetch(strategy_type) do
          raise UnsupportedSourceStrategy, "missing DOU adapter version for #{strategy_type.inspect}"
        end
      end

      def parser_version
        PARSER_VERSIONS.fetch(strategy_type) do
          raise UnsupportedSourceStrategy, "missing DOU parser version for #{strategy_type.inspect}"
        end
      end

      def parser
        @parser ||= parser_override || strategy_parser
      end

      def strategy_parser
        case strategy_type
        when "rss" then FeedParser.new
        when "http_html" then ListingParser.new
        else
          raise UnsupportedSourceStrategy, "no DOU parser for #{strategy_type.inspect}"
        end
      end

      def source_base_url
        @source_base_url ||= SourceRegistry.fetch(SOURCE_KEY).fetch("base_url")
      end

      def request_url
        @request_url ||= begin
          uri = URI.join(source_base_url, REQUEST_PATHS.fetch(strategy_type))
          uri.query = URI.encode_www_form(search:) if search
          uri.to_s
        end
      end

      def default_run_key
        "dou:#{strategy_type}:#{Digest::SHA256.hexdigest(request_url)[0, 16]}:#{started_at.iso8601(6)}"
      end

      def vacancy_payload(vacancy)
        {
          "record_type" => "job_posting",
          "source" => SOURCE_KEY,
          "source_record_key" => vacancy.external_id,
          "url" => vacancy.url,
          "title" => vacancy.title,
          "company_name" => vacancy.respond_to?(:company_name) ? vacancy.company_name : nil,
          "location_text" => vacancy.respond_to?(:location_text) ? vacancy.location_text : nil,
          "summary" => vacancy.summary,
          "listed_at_text" => vacancy.respond_to?(:listed_at_text) ? vacancy.listed_at_text : nil,
          "published_at" => vacancy.respond_to?(:published_at) ? vacancy.published_at&.iso8601 : nil
        }.compact
      end

      def result_for(source_run)
        Result.new(
          source_run_id: source_run.typed_id,
          status: source_run.status,
          strategy: source_run.provenance["strategy"],
          request_url: source_run.provenance["request_url"],
          fetched_count: source_run.fetched_count,
          discovered_count: source_run.discovered_count,
          observed_count: source_run.observed_count,
          raw_payload_ids: source_run.raw_payloads.order(:created_at).map(&:typed_id).freeze,
          ingestion_record_ids: source_run.ingestion_records.order(:created_at).map(&:typed_id).freeze,
          observation_ids: source_run.source_observations.order(:created_at).map(&:typed_id).freeze
        )
      end

      def raise_previous_failure(source_run)
        message = [ source_run.error_class, source_run.error_message ].compact.join(": ")
        raise RunFailed, "DOU source run already failed#{": #{message}" if message.present?}"
      end

      def fail_source_run(source_run, error, fetched_count:, discovered_count:)
        SourceRuns.fail(
          source_run:,
          finished_at: normalize_finish_time(started_at),
          fetched_count:,
          discovered_count:,
          observed_count: 0,
          error_class: error.class.name,
          error_message: error.message,
          error_details: {
            "request_url" => request_url,
            "strategy" => strategy_type
          }
        )
      end

      def normalize_finish_time(floor)
        finished_at = normalize_time(clock.call)
        finished_at < floor ? floor : finished_at
      end

      def normalize_time(value)
        time = value.respond_to?(:in_time_zone) ? value.in_time_zone : Time.zone.parse(value.to_s)
        time || raise(ArgumentError, "invalid time value")
      end
    end
  end
end
