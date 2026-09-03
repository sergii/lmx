# frozen_string_literal: true

require "rails_helper"

RSpec.describe Acquisition::Dou, type: :model do
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
  let(:feed_body) { Rails.root.join("packs/acquisition/spec/fixtures/dou/vacancies.xml").read }
  let(:html_body) { Rails.root.join("packs/acquisition/spec/fixtures/dou/vacancies.html").read }
  let(:feed_response) do
    FakeResponse.new(
      body: feed_body,
      status: 200,
      content_type: "application/rss+xml; charset=utf-8",
      url: "https://jobs.dou.ua/vacancies/feeds/?search=Ruby",
      fetched_at:
    )
  end
  let(:http_client) { FakeHttpClient.new(response: feed_response) }
  let(:clock) { -> { finished_at } }

  it "parses stable facts and publication time from the DOU RSS feed" do
    vacancies = Acquisition::Dou::FeedParser.new.parse(feed_body, base_url: "https://jobs.dou.ua/")

    expect(vacancies.map(&:external_id)).to eq(%w[379948 380001])
    expect(vacancies.first).to have_attributes(
      title: "Senior Ruby Engineer в Acme Labs, Київ, віддалено",
      url: "https://jobs.dou.ua/companies/acme/vacancies/379948/",
      summary: "Rails, PostgreSQL, AWS. Product team.",
      published_at: Time.zone.parse("2026-09-02 09:30:00 UTC")
    )
  end

  it "uses RSS as the configured primary DOU adapter and persists durable evidence" do
    result = described_class.collect(
      search: "Ruby",
      run_key: "dou:rss:ruby:2026-09-02T20:00:00Z",
      started_at:,
      http_client:,
      clock:
    )

    expect(result).to have_attributes(
      status: "succeeded",
      strategy: "rss",
      request_url: "https://jobs.dou.ua/vacancies/feeds/?search=Ruby",
      fetched_count: 1,
      discovered_count: 2,
      observed_count: 2
    )
    expect(result.raw_payload_ids.size).to eq(1)
    expect(result.ingestion_record_ids.size).to eq(1)
    expect(result.observation_ids.size).to eq(2)

    source_run = SourceRun.find_by_typed_id!(result.source_run_id)
    raw = source_run.raw_payloads.sole
    ingestion = source_run.ingestion_records.sole
    observations = source_run.source_observations.order(:external_id)

    expect(source_run).to have_attributes(
      transport: "rss",
      adapter_version: "dou-rss-v1",
      parser_version: "dou-rss-v1"
    )
    expect(raw.body.b).to eq(feed_body.b)
    expect(raw.source_uri).to eq("https://jobs.dou.ua/vacancies/feeds/?search=Ruby")
    expect(raw.content_type).to eq("application/rss+xml; charset=utf-8")
    expect(ingestion.raw_payload_id).to eq(raw.id)
    expect(observations.map(&:external_id)).to eq(%w[379948 380001])
    expect(observations.first).to have_attributes(
      source_published_at: Time.zone.parse("2026-09-02 09:30:00 UTC")
    )
    expect(observations.first.payload).to include(
      "record_type" => "job_posting",
      "title" => "Senior Ruby Engineer в Acme Labs, Київ, віддалено",
      "published_at" => "2026-09-02T09:30:00Z"
    )
    expect(observations.first.metadata).to include(
      "evidence_kind" => "job_posting_feed_entry",
      "strategy" => "rss"
    )
    expect { observations.first.update!(payload: {}) }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "keeps HTML as an explicit fallback adapter with richer listing-card facts" do
    html_response = FakeResponse.new(
      body: html_body,
      status: 200,
      content_type: "text/html; charset=utf-8",
      url: "https://jobs.dou.ua/vacancies/?search=Ruby",
      fetched_at:
    )

    result = described_class.collect(
      search: "Ruby",
      strategy: "http_html",
      run_key: "dou:html:ruby:2026-09-02T20:00:00Z",
      started_at:,
      http_client: FakeHttpClient.new(response: html_response),
      clock:
    )

    expect(result).to have_attributes(
      status: "succeeded",
      strategy: "http_html",
      request_url: "https://jobs.dou.ua/vacancies/?search=Ruby",
      observed_count: 2
    )

    source_run = SourceRun.find_by_typed_id!(result.source_run_id)
    expect(source_run).to have_attributes(
      transport: "http_scrape",
      adapter_version: "dou-http-html-v1",
      parser_version: "dou-listing-v1"
    )
    expect(source_run.source_observations.order(:external_id).first.payload).to include(
      "title" => "Senior Ruby Engineer",
      "company_name" => "Acme Labs",
      "location_text" => "Київ, віддалено"
    )
  end

  it "replays the same successful RSS run without another HTTP request or duplicate evidence" do
    attributes = {
      search: "Ruby",
      run_key: "dou:rss:retry-safe",
      started_at:,
      http_client:,
      clock:
    }

    first = described_class.collect(**attributes)
    second = described_class.collect(**attributes)

    expect(second).to eq(first)
    expect(http_client.calls).to eq([ "https://jobs.dou.ua/vacancies/feeds/?search=Ruby" ])
    expect(SourceRun.count).to eq(1)
    expect(RawPayload.count).to eq(1)
    expect(IngestionRecord.count).to eq(1)
    expect(SourceObservation.count).to eq(2)
  end

  it "records a successful zero-result RSS run with raw and ingestion provenance" do
    empty_response = FakeResponse.new(
      body: Rails.root.join("packs/acquisition/spec/fixtures/dou/empty.xml").read,
      status: 200,
      content_type: "application/rss+xml",
      url: "https://jobs.dou.ua/vacancies/feeds/?search=ImpossibleQuery",
      fetched_at:
    )

    result = described_class.collect(
      search: "ImpossibleQuery",
      run_key: "dou:rss:zero",
      started_at:,
      http_client: FakeHttpClient.new(response: empty_response),
      clock:
    )

    expect(result).to have_attributes(
      status: "succeeded",
      strategy: "rss",
      fetched_count: 1,
      discovered_count: 0,
      observed_count: 0
    )
    expect(result.raw_payload_ids.size).to eq(1)
    expect(result.ingestion_record_ids.size).to eq(1)
    expect(result.observation_ids).to be_empty
  end

  it "records the SourceRun failure while preserving raw RSS evidence when parsing fails" do
    parser = Object.new
    def parser.parse(*)
      raise Nokogiri::XML::SyntaxError, "fixture parse failed"
    end

    expect do
      described_class.collect(
        search: "Ruby",
        run_key: "dou:rss:parse-failure",
        started_at:,
        http_client:,
        parser:,
        clock:
      )
    end.to raise_error(Nokogiri::XML::SyntaxError, "fixture parse failed")

    source_run = SourceRun.find_by!(run_key: "dou:rss:parse-failure")
    expect(source_run).to have_attributes(
      status: "failed",
      transport: "rss",
      fetched_count: 1,
      discovered_count: 0,
      observed_count: 0,
      error_class: "Nokogiri::XML::SyntaxError"
    )
    expect(source_run.raw_payloads.count).to eq(1)
    expect(source_run.ingestion_records.count).to eq(1)
    expect(source_run.source_observations.count).to eq(0)
  end

  it "records RSS transport failure as a failed SourceRun without silently switching transports" do
    error = Net::ReadTimeout.new("source timed out")

    expect do
      described_class.collect(
        run_key: "dou:rss:http-failure",
        started_at:,
        http_client: FakeHttpClient.new(error:),
        clock:
      )
    end.to raise_error(Net::ReadTimeout)

    source_run = SourceRun.find_by!(run_key: "dou:rss:http-failure")
    expect(source_run).to have_attributes(
      status: "failed",
      transport: "rss",
      fetched_count: 0,
      discovered_count: 0,
      observed_count: 0,
      error_class: "Net::ReadTimeout"
    )
    expect(source_run.raw_payloads).to be_empty
    expect(SourceRun.where(transport: "http_scrape")).to be_empty
  end
end
