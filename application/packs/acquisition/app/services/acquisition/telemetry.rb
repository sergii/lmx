# frozen_string_literal: true

require "uri"

module Acquisition
  module Telemetry
    ROOT_SPAN = "lmx.acquisition.collect"
    FETCH_SPAN = "lmx.acquisition.fetch"
    PARSE_SPAN = "lmx.acquisition.parse"
    PERSIST_OBSERVATION_SPAN = "lmx.acquisition.persist_observation"

    ACQUISITION_DURATION = "lmx.acquisition.duration"
    SOURCE_FETCH_TOTAL = "lmx.source.fetch.total"
    PARSER_FAILURE_TOTAL = "lmx.parser.failure.total"

    TRANSPORTS = {
      "rss" => "rss",
      "http_api" => "http_api",
      "http_html" => "http_scrape",
      "browser" => "browser"
    }.freeze

    class << self
      def collect(
        source_key:,
        search:,
        requested_strategy:,
        collector_version:,
        adapter_versions:,
        parser_versions:,
        http_client:,
        parser:,
        parser_factory:,
        &block
      )
        strategy_type = resolve_strategy(source_key, requested_strategy)
        transport = TRANSPORTS[strategy_type]
        attributes = {
          "lmx.source.id" => source_key,
          "lmx.source.transport" => transport,
          "lmx.source.strategy" => strategy_type,
          "lmx.source.search_present" => search.to_s.strip != "",
          "lmx.source.collector_version" => collector_version,
          "lmx.source.adapter_version" => adapter_versions[strategy_type],
          "lmx.source.parser_version" => parser_versions[strategy_type]
        }
        started_at = monotonic_time
        outcome = "failure"

        Platform::Telemetry.in_span(ROOT_SPAN, attributes:) do |span|
          effective_parser = parser || build_parser(strategy_type, parser_versions, parser_factory)
          instrumented_http_client = HttpClientProxy.new(http_client, source_key:, transport:)
          instrumented_parser = if effective_parser
            ParserProxy.new(
              effective_parser,
              source_key:,
              transport:,
              parser_version: parser_versions[strategy_type]
            )
          end

          result = block.call(instrumented_http_client, instrumented_parser)
          outcome = result.status.to_s == "succeeded" ? "success" : "failure"
          Platform::Telemetry.add_attributes(span, result_attributes(result))
          result
        end
      ensure
        if defined?(started_at) && started_at
          Platform::Telemetry.record(
            ACQUISITION_DURATION,
            monotonic_time - started_at,
            unit: "s",
            description: "Acquisition collector duration",
            attributes: {
              "lmx.source.id" => source_key,
              "lmx.source.transport" => transport,
              "lmx.outcome" => outcome
            }
          )
        end
      end

      private

      def resolve_strategy(source_key, requested_strategy)
        requested_strategy = requested_strategy.to_s.strip
        return requested_strategy unless requested_strategy.empty?

        SourceRegistry.primary_strategy(source_key)&.fetch("type", nil)
      end

      def build_parser(strategy_type, parser_versions, parser_factory)
        return unless strategy_type && parser_versions.key?(strategy_type)

        parser_factory.call(strategy_type)
      end

      def result_attributes(result)
        {
          "lmx.source.run_id" => result.source_run_id,
          "lmx.source.status" => result.status,
          "lmx.source.fetched_count" => result.fetched_count,
          "lmx.source.discovered_count" => result.discovered_count,
          "lmx.source.observed_count" => result.observed_count
        }
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end

    class HttpClientProxy
      def initialize(delegate, source_key:, transport:)
        @delegate = delegate
        @source_key = source_key
        @transport = transport
      end

      def get(url)
        uri = URI.parse(url)
        attributes = {
          "lmx.source.id" => source_key,
          "lmx.source.transport" => transport,
          "http.request.method" => "GET",
          "server.address" => uri.host
        }

        Platform::Telemetry.in_span(FETCH_SPAN, attributes:, record_exception: false) do |span|
          response = delegate.get(url)
          Platform::Telemetry.add_attributes(
            span,
            "http.response.status_code" => response.respond_to?(:status) ? response.status : nil
          )
          record_fetch("success")
          response
        rescue StandardError
          record_fetch("failure")
          raise
        end
      end

      private

      attr_reader :delegate, :source_key, :transport

      def record_fetch(outcome)
        Platform::Telemetry.increment(
          SOURCE_FETCH_TOTAL,
          description: "Source fetch attempts",
          attributes: {
            "lmx.source.id" => source_key,
            "lmx.source.transport" => transport,
            "lmx.outcome" => outcome
          }
        )
      end
    end

    class ParserProxy
      def initialize(delegate, source_key:, transport:, parser_version:)
        @delegate = delegate
        @source_key = source_key
        @transport = transport
        @parser_version = parser_version
      end

      def parse(*args, **kwargs)
        attributes = {
          "lmx.source.id" => source_key,
          "lmx.source.transport" => transport,
          "lmx.source.parser_version" => parser_version
        }

        Platform::Telemetry.in_span(PARSE_SPAN, attributes:, record_exception: false) do |span|
          items = delegate.parse(*args, **kwargs)
          Platform::Telemetry.add_attributes(
            span,
            "lmx.source.discovered_count" => items.respond_to?(:size) ? items.size : nil
          )
          ObservedCollection.new(items, source_key:, transport:)
        rescue StandardError
          Platform::Telemetry.increment(
            PARSER_FAILURE_TOTAL,
            description: "Parser failures",
            attributes: attributes
          )
          raise
        end
      end

      private

      attr_reader :delegate, :source_key, :transport, :parser_version
    end

    class ObservedCollection
      include Enumerable

      def initialize(items, source_key:, transport:)
        @items = items
        @source_key = source_key
        @transport = transport
      end

      def each(&block)
        return enum_for(:each) unless block

        items.each(&block)
      end

      def size
        items.size
      end

      def select(&block)
        return enum_for(:select) unless block

        self.class.new(items.select(&block), source_key:, transport:)
      end

      def map(&block)
        return enum_for(:map) unless block

        attributes = {
          "lmx.source.id" => source_key,
          "lmx.source.transport" => transport
        }

        Platform::Telemetry.in_span(PERSIST_OBSERVATION_SPAN, attributes:, record_exception: false) do |span|
          result = items.map(&block)
          Platform::Telemetry.add_attributes(span, "lmx.source.observed_count" => result.size)
          result
        end
      end

      private

      attr_reader :items, :source_key, :transport
    end
  end
end
