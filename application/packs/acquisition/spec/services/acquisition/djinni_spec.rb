# frozen_string_literal: true

require "rails_helper"

RSpec.describe Acquisition::Djinni, type: :model do
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
  let(:feed_body) { Rails.root.join("packs/acquisition/spec/fixtures/djinni/vacancies.xml").read }
  let(:feed_response) do
    FakeResponse.new(
      body: feed_body,
      status: 200,
      content_type: "application/rss+xml; charset=utf-8",
      url: "https://djinni.co/jobs/rss/?keywords=Ruby",
      fetched_at:
    )
  end
  let(:http_client) { FakeHttpClient.new(response: feed_response) }
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

  it "uses RSS as the configured primary Djinni adapter and persists durable evidence" do
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
      request_url: "https://djinni.co/jobs/rss/?keywords=Ruby",
      fetched_count: 1,
      discovered_count: 2,
      observed_count: 2
    )

    source_run = SourceRun.find_by_typed_id!(result.source_run_id)
    raw = source_run.raw_payloads.sole
    observations = source_run.source_observations.order(:external_id)

    expect(source_run).to have_attributes(
      transport: "rss",
      adapter_version: "djinni-rss-v1",
      parser_version: "djinni-rss-v1"
    )
    expect(raw.body.b).to eq(feed_body.b)
    expect(raw.source_uri).to eq("https://djinni.co/jobs/rss/?keywords=Ruby")
    expect(observations.map(&:external_id)).to eq(%w[742001 742002])
    expect(observations.first).to have_attributes(
      source_published_at: Time.zone.parse("2026-09-02 09:30:00 UTC")
    )
    expect(observations.first.payload).to include(
      "record_type" => "job_posting",
      "source" => "djinni",
      "title" => "Senior Ruby on Rails Engineer",
      "published_at" => "2026-09-02T09:30:00Z"
    )
    expect(observations.first.metadata).to include(
      "evidence_kind" => "job_posting_feed_entry",
      "strategy" => "rss"
    )
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
    expect(http_client.calls).to eq([ "https://djinni.co/jobs/rss/?keywords=Ruby" ])
    expect(SourceRun.count).to eq(1)
    expect(RawPayload.count).to eq(1)
    expect(IngestionRecord.count).to eq(1)
    expect(SourceObservation.count).to eq(2)
  end

  it "records RSS transport failure without silently switching transports" do
    error = Net::ReadTimeout.new("source timed out")

    expect do
      described_class.collect(
        run_key: "djinni:rss:http-failure",
        started_at:,
        http_client: FakeHttpClient.new(error:),
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
