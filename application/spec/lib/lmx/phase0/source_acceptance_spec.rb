# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lmx::Phase0::SourceAcceptance do
  Result = Data.define(:source_run_id, :status, :fetched_count, :discovered_count, :observed_count)

  let(:source_catalog) { class_double(Acquisition::SourceCatalog, active_source_ids: %w[dou djinni]) }
  let(:source_health) { class_double(Acquisition::SourceHealth) }
  let(:replay) { class_double(Acquisition::Replay) }
  let(:runner) { instance_double(Proc) }
  let(:clock) { -> { Time.zone.parse("2026-09-05 18:00:00") } }

  subject(:acceptance) do
    described_class.new(
      source_catalog:,
      source_health:,
      replay:,
      runner: ->(source_key) { runner.call(source_key) },
      clock:
    )
  end

  it "proves a live source created durable observations and replayable raw evidence" do
    allow(source_health).to receive(:fetch).with("dou").and_return(
      {
        source_key: "dou",
        status: "succeeded",
        latest_run_id: "source_run_old",
        last_successful_at: 10.minutes.ago
      },
      {
        source_key: "dou",
        status: "succeeded",
        latest_run_id: "source_run_new",
        last_successful_at: Time.zone.parse("2026-09-05 18:00:03")
      }
    )
    allow(runner).to receive(:call).with("dou").and_return(
      [
        Result.new(
          source_run_id: "source_run_new",
          status: "succeeded",
          fetched_count: 1,
          discovered_count: 4,
          observed_count: 4
        )
      ]
    )
    allow(replay).to receive(:call).with(
      source_key: "dou",
      from: Time.zone.parse("2026-09-05 17:59:59"),
      limit: 1,
      apply: false
    ).and_return(selected_raw_payloads: 1)

    result = acceptance.call(source_keys: [ "dou" ])

    expect(result.fetch(:status)).to eq("pass")
    expect(result.fetch(:sources).sole).to include(
      source_key: "dou",
      status: "pass",
      run_ids: [ "source_run_new" ],
      fetched_count: 1,
      discovered_count: 4,
      observed_count: 4,
      latest_run_id: "source_run_new",
      replayable_raw_payload: true,
      failures: []
    )
    expect(result).to be_frozen
    expect(result.fetch(:sources)).to be_frozen
  end

  it "fails explicitly when a live fetch succeeds but yields no observations" do
    allow(source_health).to receive(:fetch).with("dou").and_return(
      { source_key: "dou", status: "succeeded", latest_run_id: "source_run_old" },
      { source_key: "dou", status: "succeeded", latest_run_id: "source_run_new", last_successful_at: clock.call }
    )
    allow(runner).to receive(:call).with("dou").and_return(
      Result.new(
        source_run_id: "source_run_new",
        status: "succeeded",
        fetched_count: 1,
        discovered_count: 0,
        observed_count: 0
      )
    )
    allow(replay).to receive(:call).and_return(selected_raw_payloads: 1)

    source = acceptance.call(source_keys: "dou").fetch(:sources).sole

    expect(source.fetch(:status)).to eq("fail")
    expect(source.fetch(:failures)).to include("live collection produced no source observations")
  end

  it "reports a collector exception without preventing the remaining source from being checked" do
    allow(source_health).to receive(:fetch).with("dou").and_return(
      { source_key: "dou", status: "never_run", latest_run_id: nil }
    )
    allow(runner).to receive(:call).with("dou").and_raise(SocketError, "network unavailable")

    allow(source_health).to receive(:fetch).with("djinni").and_return(
      { source_key: "djinni", status: "succeeded", latest_run_id: "source_run_old" },
      { source_key: "djinni", status: "succeeded", latest_run_id: "source_run_new", last_successful_at: clock.call }
    )
    allow(runner).to receive(:call).with("djinni").and_return(
      Result.new(
        source_run_id: "source_run_new",
        status: "succeeded",
        fetched_count: 1,
        discovered_count: 2,
        observed_count: 2
      )
    )
    allow(replay).to receive(:call).with(
      source_key: "djinni",
      from: Time.zone.parse("2026-09-05 17:59:59"),
      limit: 1,
      apply: false
    ).and_return(selected_raw_payloads: 1)

    result = acceptance.call(source_keys: %w[dou djinni])

    expect(result.fetch(:status)).to eq("fail")
    expect(result.fetch(:sources).first).to include(
      source_key: "dou",
      status: "fail",
      error: { class: "SocketError", message: "network unavailable" }
    )
    expect(result.fetch(:sources).last.fetch(:status)).to eq("pass")
  end

  it "rejects inactive or unknown source keys before performing any network work" do
    expect(runner).not_to receive(:call)

    expect do
      acceptance.call(source_keys: "dou,missing")
    end.to raise_error(ArgumentError, "inactive or unknown acquisition source(s): missing")
  end
end
