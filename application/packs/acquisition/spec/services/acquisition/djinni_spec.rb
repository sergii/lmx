# frozen_string_literal: true

require "rails_helper"

RSpec.describe Acquisition::Djinni, type: :model do
  let(:response_class) { Data.define(:body, :status, :content_type, :url, :fetched_at) }
  let(:http_client_class) do
    Class.new do
      attr_reader :calls

      def initialize(responses:)
        @responses = responses.dup
        @calls = []
      end

      def get(url)
        @calls << url
        response = @responses.shift || raise("no fake response configured for #{url}")
        raise response if response.is_a?(Exception)

        response
      end
    end
  end

  let(:started_at) { Time.zone.parse("2026-09-02 20:00:00") }
  let(:fetched_at) { started_at + 1.second }
  let(:finished_at) { started_at + 2.seconds }
  let(:feed_body) { Rails.root.join("packs/acquisition/spec/fixtures/djinni/vacancies.xml").read }
  let(:listing_body) { Rails.root.join("packs/acquisition/spec/fixtures/djinni/listing.html").read }
  let(:feed_url) { "https://djinni.co/jobs/rss/?primary_keyword=Ruby" }
  let(:listing_url) { "https://djinni.co/jobs/?primary_keyword=Ruby" }
  let(:feed_response) do
    response_class.new(
      body: feed_body,
      status: 200,
      content_type: "application/rss+xml; charset=utf-8",
      url: feed_url,
      fetched_at:
    )
  end
  let(:listing_response) do
    response_class.new(
      body: listing_body,
      status: 200,
      content_type: "text/html; charset=utf-8",
      url: listing_url,
      fetched_at: fetched_at + 0.1
    )
  end
  let(:http_client) { http_client_class.new(responses: [ feed_response, listing_response ]) }
  let(:clock) { -> { finished_at } }

  it "parses stable facts and publication time from the Djinni RSS feed" do
    vacancies = Acquisition::Djinni::FeedParser.new.parse(feed_body, base_url: "https://djinni.co/")

    expect(vacancies.map(&:external_id)).to eq(%w[742001 742002])
    expect(vacancies.first).to have_attributes(
      title: "Senior Ruby on Rails Engineer",
      url: "https://djinni.co/jobs/742001-senior-ruby-on-rails-engineer/",
      summary: "Rails, PostgreSQL, AWS. Product team.",
      published_at: Time.zone.parse("2026-09-02 09:30:00 UTC")
    )
  end

  it "parses company, location, and compensation from the matching Djinni listing" do
    enrichments = Acquisition::Djinni::ListingEnrichmentParser.new.parse(listing_body)

    expect(enrichments.first).to have_attributes(
      external_id: "742001",
      company_name: "Acme Labs",
      location_text: "Full Remote · Ukraine",
      compensation_text: "$4000-6000"
    )
    expect(enrichments.second).to have_attributes(
      external_id: "742002",
      company_name: "Example Product",
      location_text: "Office Work · Poland (Warsaw)",
      compensation_text: nil
    )
  end

  it "uses the Djinni primary keyword filter and enriches RSS observations from listing HTML" do
    result = described_class.collect(
      search: "Ruby",
      run_key: "djinni:rss:ruby:2026-09-02T20:00:00Z",
      started_at:,
      http_client:,
      clock:
    )

    expect(result).to have_attributes(
      status: "succeeded",
      strategy: "rss",
      request_url: feed_url,
      fetched_count: 2,
      discovered_count: 2,
      observed_count: 2
    )
    expect(http_client.calls).to eq([ feed_url, listing_url ])

    source_run = SourceRun.find_by_typed_id!(result.source_run_id)
    feed_raw = source_run.raw_payloads.find_by!(source_uri: feed_url)
    listing_raw = source_run.raw_payloads.find_by!(source_uri: listing_url)
    observations = source_run.source_observations.order(:external_id)

    expect(source_run).to have_attributes(
      transport: "rss",
      adapter_version: "djinni-rss-v1",
      parser_version: "djinni-rss-v1"
    )
    expect(source_run.raw_payloads.count).to eq(2)
    expect(source_run.ingestion_records.count).to eq(1)
    expect(feed_raw.body.b).to eq(feed_body.b)
    expect(listing_raw.body.b).to eq(listing_body.b)
    expect(observations.map(&:external_id)).to eq(%w[742001 742002])
    expect(observations.first).to have_attributes(
      source_published_at: Time.zone.parse("2026-09-02 09:30:00 UTC")
    )
    expect(observations.first.payload).to include(
      "record_type" => "job_posting",
      "source" => "djinni",
      "title" => "Senior Ruby on Rails Engineer",
      "company_name" => "Acme Labs",
      "location_text" => "Full Remote · Ukraine",
      "compensation_text" => "$4000-6000",
      "published_at" => "2026-09-02T09:30:00Z"
    )
    expect(observations.first.metadata).to include(
      "evidence_kind" => "job_posting_feed_entry",
      "strategy" => "rss",
      "listing_enrichment" => include(
        "raw_payload_id" => listing_raw.typed_id,
        "request_url" => listing_url,
        "parser_version" => "djinni-listing-enrichment-v1"
      )
    )
  end

  it "keeps the RSS run usable when optional listing enrichment fails" do
    enrichment_error = Net::ReadTimeout.new("listing timed out")
    client = http_client_class.new(responses: [ feed_response, enrichment_error ])

    result = described_class.collect(
      search: "Ruby",
      run_key: "djinni:rss:enrichment-failure",
      started_at:,
      http_client: client,
      clock:
    )

    expect(result).to have_attributes(status: "succeeded", fetched_count: 1, observed_count: 2)
    expect(client.calls).to eq([ feed_url, listing_url ])
    expect(SourceRun.find_by_typed_id!(result.source_run_id).raw_payloads.count).to eq(1)
    expect(SourceObservation.order(:external_id).first.payload).not_to have_key("company_name")
  end

  it "replays the same successful RSS run without another HTTP request or duplicate evidence" do
    attributes = {
      search: "Ruby",
      run_key: "djinni:rss:retry-safe",
      started_at:,
      http_client:,
      clock:
    }

    first = described_class.collect(**attributes)
    second = described_class.collect(**attributes)

    expect(second).to eq(first)
    expect(http_client.calls).to eq([ feed_url, listing_url ])
    expect(SourceRun.count).to eq(1)
    expect(RawPayload.count).to eq(2)
    expect(IngestionRecord.count).to eq(1)
    expect(SourceObservation.count).to eq(2)
  end

  it "records RSS transport failure without silently switching transports" do
    error = Net::ReadTimeout.new("source timed out")

    expect do
      described_class.collect(
        run_key: "djinni:rss:http-failure",
        started_at:,
        http_client: http_client_class.new(responses: [ error ]),
        clock:
      )
    end.to raise_error(Net::ReadTimeout)

    source_run = SourceRun.find_by!(run_key: "djinni:rss:http-failure")
    expect(source_run).to have_attributes(
      status: "failed",
      transport: "rss",
      fetched_count: 0,
      discovered_count: 0,
      observed_count: 0,
      error_class: "Net::ReadTimeout"
    )
    expect(source_run.raw_payloads).to be_empty
  end
end
