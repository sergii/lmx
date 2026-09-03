# frozen_string_literal: true

require "rails_helper"

RSpec.describe Acquisition::RecordSourceObservation, type: :model do
  let(:started_at) { Time.zone.parse("2026-09-02 00:10:00") }
  let(:observed_at) { Time.zone.parse("2026-09-02 00:10:15.123456") }
  let(:source_run) do
    Acquisition::SourceRuns.start(
      source_key: "dou",
      transport: "http_scrape",
      started_at:,
      run_key: "dou:test-run",
      collector_version: "collector-1.2.0",
      adapter_version: "dou-http-3",
      parser_version: "dou-parser-7",
      provenance: { "worker" => "collector-01" }
    )
  end
  let(:raw_html) { "<html><body>Senior Ruby Engineer</body></html>" }
  let(:attributes) do
    {
      source_run:,
      observed_at:,
      raw_payload: raw_html,
      source_uri: "https://jobs.dou.ua/companies/example/vacancies/123/",
      content_type: "text/html",
      encoding: "UTF-8",
      external_id: "jobs/123",
      original_url: "https://jobs.dou.ua/companies/example/vacancies/123/",
      canonical_url: "https://jobs.dou.ua/companies/example/vacancies/123/",
      source_published_at: Time.zone.parse("2026-09-01 18:00:00"),
      source_updated_at: Time.zone.parse("2026-09-01 20:00:00"),
      presence_state: "present",
      ingress_interface: "api",
      payload: {
        "title" => "Senior Ruby Engineer",
        "company" => "Example"
      },
      raw_provenance: { "http_status" => 200, "etag" => "abc123" },
      ingestion_provenance: { "request_id" => "req-123" },
      metadata: { "evidence_level" => "LISTED" }
    }
  end

  it "persists immutable raw evidence, ingestion provenance, and the source observation" do
    observation = nil

    expect do
      observation = described_class.call(**attributes)
    end.to change(SourceObservation, :count).by(1)
      .and change(RawPayload, :count).by(1)
      .and change(IngestionRecord, :count).by(1)

    raw = observation.raw_payload
    ingestion = observation.ingestion_record

    expect(raw).to have_attributes(
      source_run_id: source_run.id,
      source_uri: attributes.fetch(:source_uri),
      content_type: "text/html",
      encoding: "UTF-8",
      body: raw_html.b,
      byte_size: raw_html.bytesize,
      captured_at: observed_at
    )
    expect(raw.content_digest).to match(/\A[0-9a-f]{64}\z/)
    expect(raw.provenance).to eq("http_status" => 200, "etag" => "abc123")

    expect(ingestion).to have_attributes(
      source_run_id: source_run.id,
      raw_payload_id: raw.id,
      transport: "http_scrape",
      ingress_interface: "api",
      collector_version: "collector-1.2.0",
      adapter_version: "dou-http-3",
      parser_version: "dou-parser-7"
    )
    expect(ingestion.provenance).to eq("request_id" => "req-123")

    expect(observation).to have_attributes(
      source_run_id: source_run.id,
      ingestion_record_id: ingestion.id,
      source_key: "dou",
      transport: "http_scrape",
      external_id: "jobs/123",
      original_url: attributes.fetch(:original_url),
      observed_at:,
      presence_state: "present",
      parser_version: "dou-parser-7",
      content_digest: raw.content_digest
    )
    expect(observation.typed_id).to start_with("source_observation_")
    expect(observation.ingested_at).to eq(ingestion.ingested_at)

    expect(raw).to be_readonly
    expect(ingestion).to be_readonly
    expect(observation).to be_readonly

    changed_body = "changed".b
    expect do
      raw.update!(
        body: changed_body,
        content_digest: Digest::SHA256.hexdigest(changed_body),
        byte_size: changed_body.bytesize
      )
    end.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { ingestion.update!(parser_version: "changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { observation.update!(external_id: "jobs/changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "deduplicates a retry across raw payload, ingestion, and observation" do
    first = described_class.call(**attributes)

    expect do
      second = described_class.call(**attributes)
      expect(second.id).to eq(first.id)
      expect(second.raw_payload.id).to eq(first.raw_payload.id)
      expect(second.ingestion_record.id).to eq(first.ingestion_record.id)
    end.to change(SourceObservation, :count).by(0)
      .and change(RawPayload, :count).by(0)
      .and change(IngestionRecord, :count).by(0)
  end

  it "canonicalizes structured raw input so JSON key ordering does not change identity" do
    structured = attributes.except(:raw_payload, :content_type, :encoding).merge(
      payload: { "title" => "Senior Ruby Engineer", "company" => "Example" }
    )

    first = described_class.call(**structured)
    second = described_class.call(
      **structured.merge(payload: { "company" => "Example", "title" => "Senior Ruby Engineer" })
    )

    expect(second.id).to eq(first.id)
    expect(second.raw_payload.id).to eq(first.raw_payload.id)
  end

  it "lets several observations share one raw capture and ingestion record" do
    first = described_class.call(**attributes)
    second = described_class.call(
      **attributes.merge(
        external_id: "jobs/124",
        canonical_url: "https://jobs.dou.ua/companies/example/vacancies/124/",
        payload: { "title" => "Staff Ruby Engineer", "company" => "Example" }
      )
    )

    expect(second.id).not_to eq(first.id)
    expect(second.raw_payload.id).to eq(first.raw_payload.id)
    expect(second.ingestion_record.id).to eq(first.ingestion_record.id)
  end

  it "keeps a later unchanged observation as new evidence when it belongs to a later source run" do
    first = described_class.call(**attributes)
    later_run = Acquisition::SourceRuns.start(
      source_key: "dou",
      transport: "http_scrape",
      started_at: started_at + 5.minutes,
      run_key: "dou:test-run-later",
      collector_version: "collector-1.2.0",
      adapter_version: "dou-http-3",
      parser_version: "dou-parser-7"
    )

    second = described_class.call(
      **attributes.merge(
        source_run: later_run,
        observed_at: observed_at + 5.minutes
      )
    )

    expect(second.id).not_to eq(first.id)
    expect(second.content_digest).to eq(first.content_digest)
  end

  it "keeps exact retries safe after completion but rejects new implicit evidence on the closed run" do
    first = described_class.call(**attributes)
    Acquisition::SourceRuns.succeed(
      source_run:,
      finished_at: started_at + 1.minute,
      fetched_count: 1,
      discovered_count: 1,
      observed_count: 1
    )

    expect(described_class.call(**attributes).id).to eq(first.id)
    expect do
      described_class.call(**attributes.merge(observed_at: observed_at + 1.minute))
    end.to raise_error(described_class::SourceRunClosed)
  end

  it "supports replay with a newer parser without mutating the original evidence" do
    first = described_class.call(**attributes)
    Acquisition::SourceRuns.succeed(
      source_run:,
      finished_at: started_at + 1.minute,
      fetched_count: 1,
      discovered_count: 1,
      observed_count: 1
    )

    replayed = described_class.call(
      **attributes.merge(
        raw_payload: first.raw_payload,
        parser_version: "dou-parser-8",
        payload: attributes.fetch(:payload).merge("remote" => true),
        metadata: { "evidence_level" => "LISTED", "reprocessed" => true }
      )
    )

    expect(replayed.id).not_to eq(first.id)
    expect(replayed.raw_payload.id).to eq(first.raw_payload.id)
    expect(replayed.ingestion_record.id).not_to eq(first.ingestion_record.id)
    expect(replayed.parser_version).to eq("dou-parser-8")
    expect(first.reload.parser_version).to eq("dou-parser-7")
    expect(first.payload).not_to have_key("remote")
  end
end
