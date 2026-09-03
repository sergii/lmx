# frozen_string_literal: true

require "rails_helper"

RSpec.describe Acquisition::Replay, type: :model do
  let(:captured_at) { Time.zone.parse("2026-09-02 20:00:01") }
  let(:request_url) { "https://jobs.dou.ua/vacancies/feeds/?search=Ruby" }
  let(:feed_body) { Rails.root.join("packs/acquisition/spec/fixtures/dou/vacancies.xml").read }
  let!(:source_run) do
    Acquisition::SourceRuns.start(
      source_key: "dou",
      transport: "rss",
      started_at: captured_at - 1.second,
      run_key: "dou:legacy-replay-fixture",
      collector_version: Acquisition::Dou::COLLECTOR_VERSION,
      adapter_version: Acquisition::Dou::ADAPTER_VERSIONS.fetch("rss"),
      parser_version: "dou-rss-legacy-v0",
      provenance: {
        "request_url" => request_url,
        "search" => "Ruby",
        "strategy" => "rss"
      }
    )
  end
  let!(:raw_payload) do
    Acquisition::RecordRawPayload.call(
      source_run:,
      payload: feed_body,
      captured_at:,
      source_uri: request_url,
      content_type: "application/rss+xml; charset=utf-8",
      encoding: feed_body.encoding.name,
      provenance: {
        "http_status" => 200,
        "request_url" => request_url,
        "strategy" => "rss"
      }
    )
  end

  before do
    Acquisition::RecordSourceObservation.call(
      source_run:,
      raw_payload:,
      observed_at: captured_at,
      external_id: "379948",
      original_url: "https://jobs.dou.ua/companies/acme/vacancies/379948/",
      canonical_url: "https://jobs.dou.ua/companies/acme/vacancies/379948/",
      presence_state: "present",
      adapter_version: Acquisition::Dou::ADAPTER_VERSIONS.fetch("rss"),
      parser_version: "dou-rss-legacy-v0",
      payload: {
        "record_type" => "job_posting",
        "source" => "dou",
        "source_record_key" => "379948",
        "url" => "https://jobs.dou.ua/companies/acme/vacancies/379948/",
        "title" => "Legacy title"
      },
      ingestion_provenance: {
        "source" => "dou",
        "request_url" => request_url,
        "strategy" => "rss"
      },
      metadata: {
        "evidence_kind" => "job_posting_feed_entry",
        "extraction_method" => "dou-rss-legacy-v0",
        "strategy" => "rss"
      }
    )

    Acquisition::SourceRuns.succeed(
      source_run:,
      finished_at: captured_at + 1.second,
      fetched_count: 1,
      discovered_count: 1,
      observed_count: 1
    )
  end

  it "plans replay from persisted raw evidence without writing or fetching again" do
    before_counts = [ IngestionRecord.count, SourceObservation.count ]

    result = described_class.call(source_key: "dou")

    expect(result).to include(
      source_key: "dou",
      mode: "dry_run",
      selected_raw_payloads: 1
    )
    expect(result.fetch(:summary)).to include(
      added: 1,
      changed: 1,
      unchanged: 0,
      removed: 0,
      persisted: 0
    )
    expect(result.fetch(:raw_payloads).sole).to include(
      raw_payload_id: raw_payload.typed_id,
      parser_version: Acquisition::Dou::PARSER_VERSIONS.fetch("rss")
    )
    expect([ IngestionRecord.count, SourceObservation.count ]).to eq(before_counts)
    expect(result).to be_frozen
    expect(result.fetch(:raw_payloads)).to be_frozen
  end

  it "appends current-parser observations while retaining historical evidence and is retry-safe" do
    current_parser = Acquisition::Dou::PARSER_VERSIONS.fetch("rss")

    first = described_class.call(source_key: "dou", apply: true)

    expect(first.fetch(:summary).fetch(:persisted)).to eq(2)
    expect(SourceObservation.where(parser_version: "dou-rss-legacy-v0").count).to eq(1)
    expect(SourceObservation.where(parser_version: current_parser).count).to eq(2)
    expect(raw_payload.reload.ingestion_records.pluck(:parser_version)).to include(
      "dou-rss-legacy-v0",
      current_parser
    )

    second = described_class.call(source_key: "dou", apply: true)

    expect(second.fetch(:summary).fetch(:persisted)).to eq(0)
    expect(SourceObservation.where(parser_version: current_parser).count).to eq(2)
  end

  it "supports date-scoped dry-run backfills" do
    result = described_class.call(source_key: "dou", from: captured_at + 1.second)

    expect(result).to include(
      mode: "dry_run",
      selected_raw_payloads: 0
    )
    expect(result.fetch(:summary)).to include(
      added: 0,
      changed: 0,
      unchanged: 0,
      removed: 0,
      persisted: 0
    )
  end

  it "rejects invalid scope before processing evidence" do
    expect do
      described_class.call(source_key: "dou", from: captured_at, to: captured_at - 1.second)
    end.to raise_error(ArgumentError, "from must be before or equal to to")

    expect do
      described_class.call(source_key: "dou", limit: 0)
    end.to raise_error(ArgumentError, "limit must be a positive integer")
  end
end
