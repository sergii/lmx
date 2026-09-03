# frozen_string_literal: true

require "rails_helper"

RSpec.describe Acquisition::Telemetry do
  it "emits the Phase 0 acquisition span contract without leaking the raw search" do
    spans = []
    result_type = Data.define(:source_run_id, :status, :fetched_count, :discovered_count, :observed_count)
    response_type = Data.define(:status)

    allow(Platform::Telemetry).to receive(:in_span) do |name, attributes:, record_exception: true, &block|
      span = Struct.new(:attributes).new(attributes.dup)
      spans << { name:, attributes: span.attributes, record_exception: }
      block.call(span)
    end
    allow(Platform::Telemetry).to receive(:add_attributes) do |span, attributes|
      span.attributes.merge!(attributes.compact.transform_keys(&:to_s))
      span
    end

    http_client = double("http_client")
    parser = double("parser")
    allow(http_client).to receive(:get).and_return(response_type.new(status: 200))
    allow(parser).to receive(:parse).and_return([ :first, :second ])

    result = described_class.collect(
      source_key: "dou",
      search: "secret Ruby phrase",
      requested_strategy: nil,
      collector_version: "collector-v1",
      adapter_versions: { "rss" => "adapter-v1" },
      parser_versions: { "rss" => "parser-v1" },
      http_client:,
      parser:,
      parser_factory: ->(_) { raise "explicit parser should be used" }
    ) do |instrumented_http_client, instrumented_parser|
      instrumented_http_client.get("https://jobs.dou.ua/vacancies/feeds/?search=secret")
      observations = instrumented_parser.parse("payload").map { _1.to_s }

      result_type.new(
        source_run_id: "source_run_01test",
        status: "succeeded",
        fetched_count: 1,
        discovered_count: 2,
        observed_count: observations.size
      )
    end

    expect(result.status).to eq("succeeded")
    expect(spans.map { _1.fetch(:name) }).to eq(
      [
        "lmx.acquisition.collect",
        "lmx.acquisition.fetch",
        "lmx.acquisition.parse",
        "lmx.acquisition.observe"
      ]
    )

    root = spans.fetch(0)
    expect(root.fetch(:record_exception)).to be(true)
    expect(root.fetch(:attributes)).to include(
      "lmx.source.id" => "dou",
      "lmx.source.transport" => "rss",
      "lmx.source.strategy" => "rss",
      "lmx.source.search_present" => true,
      "lmx.source.run_id" => "source_run_01test",
      "lmx.source.status" => "succeeded",
      "lmx.source.fetched_count" => 1,
      "lmx.source.discovered_count" => 2,
      "lmx.source.observed_count" => 2
    )

    fetch = spans.fetch(1)
    expect(fetch.fetch(:record_exception)).to be(false)
    expect(fetch.fetch(:attributes)).to include(
      "http.request.method" => "GET",
      "server.address" => "jobs.dou.ua",
      "http.response.status_code" => 200
    )

    expect(spans.fetch(2).fetch(:attributes)).to include(
      "lmx.source.parser_version" => "parser-v1",
      "lmx.source.discovered_count" => 2
    )
    expect(spans.fetch(3).fetch(:attributes)).to include("lmx.source.observed_count" => 2)
    expect(spans.inspect).not_to include("secret Ruby phrase")
    expect(spans.inspect).not_to include("?search=secret")
  end
end
