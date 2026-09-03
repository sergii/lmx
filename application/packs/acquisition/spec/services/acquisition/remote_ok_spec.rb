# frozen_string_literal: true

require "rails_helper"

RSpec.describe Acquisition::RemoteOk, type: :model do
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

  let(:started_at) { Time.zone.parse("2026-09-03 02:00:00") }
  let(:fetched_at) { started_at + 1.second }
  let(:finished_at) { started_at + 2.seconds }
  let(:api_body) { Rails.root.join("packs/acquisition/spec/fixtures/remote_ok/vacancies.json").read }
  let(:request_url) { "https://remoteok.com/api" }
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

  it "parses stable job facts while ignoring the Remote OK legal metadata record" do
    vacancies = Acquisition::RemoteOk::ApiParser.new.parse(api_body, base_url: "https://remoteok.com/")

    expect(vacancies.map(&:external_id)).to eq(%w[1137001 1137002])
    expect(vacancies.first).to have_attributes(
      title: "Senior Ruby on Rails Engineer",
      company_name: "Example Product",
      location_text: "Worldwide",
      url: "https://remoteok.com/remote-jobs/remote-senior-ruby-on-rails-engineer-example-product-1137001",
      summary: "Build and operate Rails services.",
      published_at: Time.zone.parse("2026-09-02T18:45:12+00:00"),
      tags: %w[ruby rails postgresql aws],
      salary_min: 100000,
      salary_max: 140000
    )
  end

  it "persists the exact global feed before applying SEARCH as a local observation filter" do
    result = described_class.collect(
      search: "Ruby Rails",
      run_key: "remoteok:http_api:ruby-rails:2026-09-03T02:00:00Z",
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
      observed_count: 1
    )

    source_run = SourceRun.find_by_typed_id!(result.source_run_id)
    raw = source_run.raw_payloads.sole
    observation = source_run.source_observations.sole

    expect(source_run).to have_attributes(
      transport: "http_api",
      adapter_version: "remote-ok-api-v1",
      parser_version: "remote-ok-api-v1"
    )
    expect(source_run.provenance).to include(
      "search" => "Ruby Rails",
      "search_mode" => "local_filter"
    )
    expect(raw.body.b).to eq(api_body.b)
    expect(raw.source_uri).to eq(request_url)
    expect(observation).to have_attributes(
      external_id: "1137001",
      canonical_url: "https://remoteok.com/remote-jobs/remote-senior-ruby-on-rails-engineer-example-product-1137001",
      source_published_at: Time.zone.parse("2026-09-02T18:45:12+00:00")
    )
    expect(observation.payload).to include(
      "record_type" => "job_posting",
      "source" => "remoteok",
      "title" => "Senior Ruby on Rails Engineer",
      "company_name" => "Example Product",
      "location_text" => "Worldwide",
      "tags" => %w[ruby rails postgresql aws],
      "salary_min" => 100000,
      "salary_max" => 140000
    )
    expect(observation.metadata).to include(
      "evidence_kind" => "job_posting_api_record",
      "search" => "Ruby Rails",
      "search_mode" => "local_filter",
      "strategy" => "http_api"
    )
  end

  it "collects the whole feed when no local search filter is supplied" do
    result = described_class.collect(
      run_key: "remoteok:http_api:full-feed",
      started_at:,
      http_client:,
      clock:
    )

    expect(result).to have_attributes(discovered_count: 2, observed_count: 2)
    expect(SourceObservation.order(:external_id).pluck(:external_id)).to eq(%w[1137001 1137002])
  end

  it "replays the same successful API run without another request or duplicate evidence" do
    attributes = {
      search: "Ruby",
      run_key: "remoteok:http_api:retry-safe",
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
    expect(SourceObservation.count).to eq(1)
  end

  it "records API transport failure without silently switching transports" do
    error = Net::ReadTimeout.new("source timed out")

    expect do
      described_class.collect(
        run_key: "remoteok:http_api:http-failure",
        started_at:,
        http_client: FakeHttpClient.new(error:),
        clock:
      )
    end.to raise_error(Net::ReadTimeout)

    source_run = SourceRun.find_by!(run_key: "remoteok:http_api:http-failure")
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

  it "fails a source run when the API top-level document is malformed" do
    malformed = FakeResponse.new(
      body: '{"id":"1137001"}',
      status: 200,
      content_type: "application/json",
      url: request_url,
      fetched_at:
    )

    expect do
      described_class.collect(
        run_key: "remoteok:http_api:malformed",
        started_at:,
        http_client: FakeHttpClient.new(response: malformed),
        clock:
      )
    end.to raise_error(TypeError, /payload must be an array/)

    expect(SourceRun.find_by!(run_key: "remoteok:http_api:malformed")).to have_attributes(
      status: "failed",
      transport: "http_api",
      fetched_count: 1,
      discovered_count: 0,
      observed_count: 0,
      error_class: "TypeError"
    )
  end
end
