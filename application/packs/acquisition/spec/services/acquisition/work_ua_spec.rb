# frozen_string_literal: true

require "rails_helper"

RSpec.describe Acquisition::WorkUa, type: :model do
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

  let(:started_at) { Time.zone.parse("2026-09-03 01:00:00") }
  let(:fetched_at) { started_at + 1.second }
  let(:finished_at) { started_at + 2.seconds }
  let(:listing_body) { Rails.root.join("packs/acquisition/spec/fixtures/work_ua/vacancies.html").read }
  let(:request_url) { "https://www.work.ua/jobs-Ruby+on+Rails/" }
  let(:listing_response) do
    FakeResponse.new(
      body: listing_body,
      status: 200,
      content_type: "text/html; charset=utf-8",
      url: request_url,
      fetched_at:
    )
  end
  let(:http_client) { FakeHttpClient.new(response: listing_response) }
  let(:clock) { -> { finished_at } }

  it "parses stable vacancy facts from current Work.ua listing cards" do
    vacancies = Acquisition::WorkUa::ListingParser.new.parse(listing_body, base_url: "https://www.work.ua/")

    expect(vacancies.map(&:external_id)).to eq(%w[742201 742202])
    expect(vacancies.first).to have_attributes(
      title: "Senior Ruby on Rails Engineer",
      company_name: "Example Product",
      location_text: "Дистанційно",
      url: "https://www.work.ua/jobs/742201/"
    )
  end

  it "uses HTML as the configured primary adapter and persists exact durable evidence" do
    result = described_class.collect(
      search: "Ruby on Rails",
      run_key: "work_ua:http_html:ruby:2026-09-03T01:00:00Z",
      started_at:,
      http_client:,
      clock:
    )

    expect(result).to have_attributes(
      status: "succeeded",
      strategy: "http_html",
      request_url:,
      fetched_count: 1,
      discovered_count: 2,
      observed_count: 2
    )

    source_run = SourceRun.find_by_typed_id!(result.source_run_id)
    raw = source_run.raw_payloads.sole
    observations = source_run.source_observations.order(:external_id)

    expect(source_run).to have_attributes(
      transport: "http_scrape",
      adapter_version: "work-ua-html-v1",
      parser_version: "work-ua-html-v1"
    )
    expect(raw.body.b).to eq(listing_body.b)
    expect(raw.source_uri).to eq(request_url)
    expect(observations.map(&:external_id)).to eq(%w[742201 742202])
    expect(observations.first.payload).to include(
      "record_type" => "job_posting",
      "source" => "work_ua",
      "title" => "Senior Ruby on Rails Engineer",
      "company_name" => "Example Product",
      "location_text" => "Дистанційно"
    )
    expect(observations.first.metadata).to include(
      "evidence_kind" => "job_posting_listing",
      "strategy" => "http_html"
    )
  end

  it "replays the same successful HTML run without another request or duplicate evidence" do
    attributes = {
      search: "Ruby on Rails",
      run_key: "work_ua:http_html:retry-safe",
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

  it "records HTML transport failure without silently switching to a browser" do
    error = Net::ReadTimeout.new("source timed out")

    expect do
      described_class.collect(
        search: "Ruby on Rails",
        run_key: "work_ua:http_html:http-failure",
        started_at:,
        http_client: FakeHttpClient.new(error:),
        clock:
      )
    end.to raise_error(Net::ReadTimeout)

    source_run = SourceRun.find_by!(run_key: "work_ua:http_html:http-failure")
    expect(source_run).to have_attributes(
      status: "failed",
      transport: "http_scrape",
      fetched_count: 0,
      discovered_count: 0,
      observed_count: 0,
      error_class: "Net::ReadTimeout"
    )
    expect(source_run.raw_payloads).to be_empty
  end
end
