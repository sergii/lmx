# frozen_string_literal: true

require "rails_helper"

RSpec.describe Acquisition::SourceHealth, type: :model do
  let(:base_time) { Time.zone.parse("2026-09-03 00:00:00") }

  it "summarizes the latest run and consecutive failure streak without inventing health" do
    successful = start_run("successful", base_time)
    Acquisition::SourceRuns.succeed(
      source_run: successful,
      finished_at: base_time + 20.seconds,
      fetched_count: 1,
      discovered_count: 8,
      observed_count: 8
    )

    first_failure = start_run("failed-1", base_time + 10.minutes)
    Acquisition::SourceRuns.fail(
      source_run: first_failure,
      finished_at: base_time + 10.minutes + 4.seconds,
      fetched_count: 1,
      discovered_count: 0,
      observed_count: 0,
      error_class: "Net::ReadTimeout",
      error_message: "source timed out",
      error_details: { phase: "fetch", request_url: "https://jobs.dou.ua/vacancies/feeds/" }
    )

    latest_failure = start_run("failed-2", base_time + 20.minutes)
    Acquisition::SourceRuns.fail(
      source_run: latest_failure,
      finished_at: base_time + 20.minutes + 5.seconds,
      fetched_count: 1,
      discovered_count: 0,
      observed_count: 0,
      error_class: "RuntimeError",
      error_message: "parser rejected payload",
      error_details: { phase: "parse" }
    )

    health = described_class.fetch("dou")

    expect(health).to include(
      source_key: "dou",
      status: "failed",
      latest_run_id: latest_failure.typed_id,
      last_attempted_at: base_time + 20.minutes,
      last_successful_at: base_time + 20.seconds,
      transport: "rss",
      duration_ms: 5_000,
      fetched_count: 1,
      discovered_count: 0,
      observed_count: 0,
      consecutive_failures: 2,
      collector_version: "collector-v1",
      adapter_version: "adapter-v1",
      parser_version: "parser-v1"
    )
    expect(health.fetch(:error)).to eq(
      class: "RuntimeError",
      message: "parser rejected payload",
      details: { "phase" => "parse" }
    )
    expect(health).to be_frozen
    expect(health.fetch(:error)).to be_frozen
    expect(health.dig(:error, :details)).to be_frozen
  end

  it "reports configured sources with no run history as never run" do
    expect(described_class.fetch("djinni")).to include(
      source_key: "djinni",
      status: "never_run",
      latest_run_id: nil,
      last_attempted_at: nil,
      last_successful_at: nil,
      consecutive_failures: 0,
      error: nil
    )
  end

  it "fails explicitly for an unknown source" do
    expect { described_class.fetch("missing") }
      .to raise_error(KeyError, /Unknown acquisition source/)
  end

  def start_run(run_key, started_at)
    Acquisition::SourceRuns.start(
      source_key: "dou",
      transport: "rss",
      started_at:,
      run_key:,
      collector_version: "collector-v1",
      adapter_version: "adapter-v1",
      parser_version: "parser-v1"
    )
  end
end
