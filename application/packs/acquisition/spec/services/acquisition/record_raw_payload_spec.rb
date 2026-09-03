# frozen_string_literal: true

require "rails_helper"

RSpec.describe Acquisition::RecordRawPayload, type: :model do
  let(:started_at) { Time.zone.parse("2026-09-02 00:10:00") }
  let(:captured_at) { started_at + 5.seconds }
  let(:source_run) do
    Acquisition::SourceRuns.start(
      source_key: "dou",
      transport: "http_scrape",
      started_at:,
      run_key: "dou:raw-payload-test",
      collector_version: "collector-1.2.0",
      adapter_version: "dou-http-3"
    )
  end
  let(:body) { "<html>source evidence</html>" }
  let(:attributes) do
    {
      source_run:,
      payload: body,
      captured_at:,
      source_uri: "https://jobs.dou.ua/vacancies/123/",
      content_type: "text/html",
      encoding: "UTF-8",
      provenance: { "http_status" => 200, "etag" => "abc123" }
    }
  end

  it "preserves exact raw bytes and their digest as immutable evidence" do
    raw_payload = described_class.call(**attributes)

    expect(raw_payload).to have_attributes(
      source_run_id: source_run.id,
      source_uri: attributes.fetch(:source_uri),
      content_type: "text/html",
      encoding: "UTF-8",
      body: body.b,
      byte_size: body.bytesize,
      captured_at:
    )
    expect(raw_payload.typed_id).to start_with("raw_payload_")
    expect(raw_payload.content_digest).to eq(Digest::SHA256.hexdigest(body.b))
    expect(raw_payload).to be_readonly

    changed_body = "changed".b
    expect do
      raw_payload.update!(
        body: changed_body,
        content_digest: Digest::SHA256.hexdigest(changed_body),
        byte_size: changed_body.bytesize
      )
    end.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "deduplicates exact retries, including retries after the run becomes terminal" do
    first = described_class.call(**attributes)
    Acquisition::SourceRuns.fail(
      source_run:,
      finished_at: started_at + 30.seconds,
      error_class: "ParserError",
      error_message: "parser rejected the response"
    )

    expect do
      second = described_class.call(**attributes)
      expect(second.id).to eq(first.id)
      expect(second.body).to eq(body.b)
    end.not_to change(RawPayload, :count)
  end

  it "does not allow a new raw capture to be attached after the source run is terminal" do
    described_class.call(**attributes)
    Acquisition::SourceRuns.succeed(
      source_run:,
      finished_at: started_at + 30.seconds,
      fetched_count: 1,
      discovered_count: 0,
      observed_count: 0
    )

    expect do
      described_class.call(**attributes.merge(captured_at: captured_at + 1.second))
    end.to raise_error(described_class::SourceRunClosed)
  end
end
