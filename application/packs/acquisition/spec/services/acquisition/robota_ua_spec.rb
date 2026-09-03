# frozen_string_literal: true

require "rails_helper"

RSpec.describe Acquisition::RobotaUa, type: :model do
  FakeResponse = Data.define(:body, :status, :content_type, :url, :fetched_at)

  class FakeHttpClient
    attr_reader :calls

    def initialize(response: nil, error: nil)
      @response = response
      @error = error
      @calls = []
    end

    def get(url)
      @calls << url
      raise @error if @error

      @response
    end
  end

  let(:started_at) { Time.zone.parse("2026-09-02 20:00:00") }
  let(:fetched_at) { started_at + 1.second }
  let(:finished_at) { started_at + 2.seconds }
  let(:api_body) { Rails.root.join("packs/acquisition/spec/fixtures/robota_ua/vacancies.json").read }
  let(:request_url) { "https://api.robota.ua/vacancy/search?sortBy=Date&count=50&keyWords=Ruby" }
  let(:api_response) do
    FakeResponse.new(
      body: api_body,
      status: 200,
      content_type: "application/json; charset=utf-8",
      url: request_url,
      fetched_at:
    )
  end
  let(:http_client) { FakeHttpClient.new(response: api_response) }
  let(:clock) { -> { finished_at } }

  it "parses stable facts and publication time from Robota.ua API documents" do
    vacancies = Acquisition::RobotaUa::ApiParser.new.parse(api_body, base_url: "https://robota.ua/")

    expect(vacancies.map(&:external_id)).to eq(%w[742101 742102])
    expect(vacancies.first).to have_attributes(
      title: "Senior Ruby on Rails Engineer",
      company_name: "Example Product",
      location_text: "Remote",
      url: "https://robota.ua/company884201/vacancy742101",
      summary: "Build and operate Rails services.",
      published_at: Time.zone.parse("2026-09-02T18:45:12.345")
    )
  end

  it "uses HTTP API as the configured primary adapter and persists exact durable evidence" do
    result = described_class.collect(
      search: "Ruby",
      run_key: "robota_ua:http_api:ruby:2026-09-02T20:00:00Z",
      started_at:,
      http_client:,
      clock:
    )

    expect(result).to have_attributes(
      status: "succeeded",
      strategy: "http_api",
      request_url:,
      fetched_count: 1,
      discovered_count: 2,
      observed_count: 2
    )

    source_run = SourceRun.find_by_typed_id!(result.source_run_id)
    raw = source_run.raw_payloads.sole
    observations = source_run.source_observations.order(:external_id)

    expect(source_run).to have_attributes(
      transport: "http_api",
      adapter_version: "robota-ua-api-v1",
      parser_version: "robota-ua-api-v1"
    )
    expect(raw.body.b).to eq(api_body.b)
    expect(raw.source_uri).to eq(request_url)
    expect(observations.map(&:external_id)).to eq(%w[742101 742102])
    expect(observations.first).to have_attributes(
      canonical_url: "https://robota.ua/company884201/vacancy742101",
      source_published_at: Time.zone.parse("2026-09-02T18:45:12.345")
    )
    expect(observations.first.payload).to include(
      "record_type" => "job_posting",
      "source" => "robota_ua",
      "title" => "Senior Ruby on Rails Engineer",
      "company_name" => "Example Product",
      "location_text" => "Remote",
      "published_at" => Time.zone.parse("2026-09-02T18:45:12.345").iso8601
    )
    expect(observations.first.metadata).to include(
      "evidence_kind" => "job_posting_api_record",
      "strategy" => "http_api"
    )
  end

  it "replays the same successful API run without another request or duplicate evidence" do
    attributes = {
      search: "Ruby",
      run_key: "robota_ua:http_api:retry-safe",
      started_at:,
      http_client:,
      clock:
    }

    first = described_class.collect(**attributes)
    second = described_class.collect(**attributes)

    expect(second).to eq(first)
    expect(http_client.calls).to eq([ request_url ])
    expect(SourceRun.count).to eq(1)
    expect(RawPayload.count).to eq(1)
    expect(IngestionRecord.count).to eq(1)
    expect(SourceObservation.count).to eq(2)
  end

  it "records API transport failure without silently switching transports" do
    error = Net::ReadTimeout.new("source timed out")

    expect do
      described_class.collect(
        search: "Ruby",
        run_key: "robota_ua:http_api:http-failure",
        started_at:,
        http_client: FakeHttpClient.new(error:),
        clock:
      )
    end.to raise_error(Net::ReadTimeout)

    source_run = SourceRun.find_by!(run_key: "robota_ua:http_api:http-failure")
    expect(source_run).to have_attributes(
      status: "failed",
      transport: "http_api",
      fetched_count: 0,
      discovered_count: 0,
      observed_count: 0,
      error_class: "Net::ReadTimeout"
    )
    expect(source_run.raw_payloads).to be_empty
  end

  it "fails a source run when the API document collection is malformed" do
    malformed = FakeResponse.new(
      body: '{"total":1,"documents":{}}',
      status: 200,
      content_type: "application/json",
      url: request_url,
      fetched_at:
    )

    expect do
      described_class.collect(
        search: "Ruby",
        run_key: "robota_ua:http_api:malformed",
        started_at:,
        http_client: FakeHttpClient.new(response: malformed),
        clock:
      )
    end.to raise_error(TypeError, /documents must be an array/)

    expect(SourceRun.find_by!(run_key: "robota_ua:http_api:malformed")).to have_attributes(
      status: "failed",
      transport: "http_api",
      fetched_count: 1,
      discovered_count: 0,
      observed_count: 0,
      error_class: "TypeError"
    )
  end
end
