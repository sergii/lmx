# frozen_string_literal: true

require "uri"

module Acquisition
  module Telemetry
    ROOT_SPAN = "lmx.acquisition.collect"
    FETCH_SPAN = "lmx.acquisition.fetch"
    PARSE_SPAN = "lmx.acquisition.parse"
    OBSERVE_SPAN = "lmx.acquisition.observe"

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
          Platform::Telemetry.add_attributes(span, result_attributes(result))
          result
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
          response
        end
      end

      private

      attr_reader :delegate, :source_key, :transport
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

        Platform::Telemetry.in_span(OBSERVE_SPAN, attributes:, record_exception: false) do |span|
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
