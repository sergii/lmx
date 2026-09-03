# frozen_string_literal: true

require "rails_helper"

RSpec.describe Acquisition::SourceRuns, type: :model do
  let(:started_at) { Time.zone.parse("2026-09-02 00:10:00") }
  let(:start_attributes) do
    {
      source_key: "dou",
      transport: "http_scrape",
      started_at:,
      run_key: "dou:2026-09-02T00:10:00Z",
      collector_version: "collector-1.2.0",
      adapter_version: "dou-http-3",
      parser_version: "dou-parser-7",
      provenance: { "worker" => "collector-01", "request_id" => "req-123" }
    }
  end

  it "starts a source run with replay and source-health provenance" do
    source_run = nil

    expect do
      source_run = described_class.start(**start_attributes)
    end.to change(SourceRun, :count).by(1)

    expect(source_run).to have_attributes(
      source_key: "dou",
      transport: "http_scrape",
      status: "running",
      started_at:,
      collector_version: "collector-1.2.0",
      adapter_version: "dou-http-3",
      parser_version: "dou-parser-7"
    )
    expect(source_run.typed_id).to start_with("source_run_")
    expect(source_run.idempotency_key).to match(/\A[0-9a-f]{64}\z/)
  end

  it "keeps acquisition transport distinct from ingress interfaces" do
    expect do
      described_class.start(**start_attributes.merge(transport: "webhook"))
    end.to raise_error(ArgumentError, /unsupported acquisition transport/)
  end

  it "deduplicates a retry of the same source-run start even after completion" do
    first = described_class.start(**start_attributes)

    expect do
      second = described_class.start(**start_attributes)
      expect(second.id).to eq(first.id)
    end.not_to change(SourceRun, :count)

    described_class.succeed(
      source_run: first,
      finished_at: started_at + 1.minute,
      observed_count: 0
    )

    expect(described_class.start(**start_attributes).id).to eq(first.id)
  end

  it "rejects reuse of a run key with different start attributes" do
    described_class.start(**start_attributes)

    expect do
      described_class.start(**start_attributes.merge(started_at: started_at + 1.second))
    end.to raise_error(described_class::IdempotencyConflict)
  end

  it "distinguishes a successful zero-result run from a failed run" do
    successful = described_class.start(**start_attributes)
    failed = described_class.start(
      **start_attributes.merge(run_key: "dou:failed", started_at: started_at + 5.minutes)
    )

    described_class.succeed(
      source_run: successful,
      finished_at: started_at + 30.seconds,
      fetched_count: 0,
      discovered_count: 0,
      observed_count: 0
    )
    described_class.fail(
      source_run: failed,
      finished_at: started_at + 5.minutes + 10.seconds,
      error_class: "Net::ReadTimeout",
      error_message: "source timed out"
    )

    expect(successful.reload).to have_attributes(
      status: "succeeded",
      fetched_count: 0,
      discovered_count: 0,
      observed_count: 0,
      error_class: nil,
      error_message: nil
    )
    expect(failed.reload).to have_attributes(
      status: "failed",
      fetched_count: nil,
      discovered_count: nil,
      observed_count: nil,
      error_class: "Net::ReadTimeout",
      error_message: "source timed out"
    )
  end

  it "makes source-run completion idempotent and terminal" do
    source_run = described_class.start(**start_attributes)
    completion = {
      source_run:,
      finished_at: started_at + 1.minute,
      fetched_count: 20,
      discovered_count: 12,
      observed_count: 12
    }

    first = described_class.succeed(**completion)
    second = described_class.succeed(**completion)

    expect(second.id).to eq(first.id)
    expect do
      described_class.fail(
        source_run:,
        finished_at: started_at + 1.minute,
        error_class: "RuntimeError",
        error_message: "late failure"
      )
    end.to raise_error(described_class::InvalidTransition)
    expect { source_run.reload.update!(observed_count: 13) }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
