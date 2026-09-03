# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lmx::Phase0::Readiness, type: :model do
  class FakePhase0Connection
    attr_reader :queries

    def initialize(rows:)
      @rows = rows
      @queries = []
    end

    def select_value(sql)
      @queries << sql
      1
    end

    def select_all(sql)
      @queries << sql
      @rows
    end

    def adapter_name
      "PostgreSQL"
    end
  end

  let(:now) { Time.zone.parse("2026-09-03 13:00:00 UTC") }
  let(:env) do
    {
      "LMX_PHASE0_WORKSPACE_ID" => "organization_01k4",
      "TELEGRAM_BOT_TOKEN" => "bot-secret",
      "TELEGRAM_CHAT_ID" => "-100123",
      "OTEL_TRACES_EXPORTER" => "otlp",
      "OTEL_SERVICE_NAME" => "lmx"
    }
  end
  let(:rls_rows) do
    described_class::PHASE0_RLS_TABLES.map do |table|
      {
        "table_name" => table,
        "rls_enabled" => true,
        "rls_forced" => true,
        "has_policy" => true
      }
    end
  end
  let(:connection) { FakePhase0Connection.new(rows: rls_rows) }
  let(:source_catalog) { class_double(Acquisition::SourceCatalog, active_source_ids: [ "dou" ]) }
  let(:source_health) do
    class_double(
      Acquisition::SourceHealth,
      all: [
        {
          source_key: "dou",
          status: "succeeded",
          last_successful_at: now - 5.minutes,
          consecutive_failures: 0,
          observed_count: 2
        }
      ]
    )
  end
  let(:replay) do
    class_double(
      Acquisition::Replay,
      call: {
        selected_raw_payloads: 1,
        raw_payloads: [ { parser_version: "dou-rss-v1" } ]
      }
    )
  end
  let(:telegram_health) { class_double(Delivery::TelegramHealth, check: { reachable: true }) }
  let(:workspace_api) { class_double(Workspace::Api) }
  let(:recurring_config) do
    lambda do
      {
        "production" => {
          "acquisition_dou" => {
            "class" => "AcquisitionCollectionJob",
            "args" => [ "dou" ],
            "schedule" => "every 10 minutes"
          },
          "delivery_telegram" => {
            "class" => "DeliveryOutboxJob",
            "queue" => "delivery",
            "schedule" => "every minute"
          }
        }
      }
    end
  end

  before do
    allow(workspace_api).to receive(:with_workspace) do |workspace_id:, &block|
      expect(workspace_id).to eq("organization_01k4")
      block.call
    end
  end

  def readiness(**overrides)
    options = {
      env:,
      clock: -> { now },
      connection: -> { connection },
      recurring_config:,
      source_catalog:,
      source_health:,
      replay:,
      telegram_health:,
      workspace_api:,
      pending_migrations_check: -> { true }
    }.merge(overrides)

    described_class.new(**options)
  end

  it "reports ready only when every Phase 0 operational check passes" do
    result = readiness.call

    expect(result.fetch(:status)).to eq("ready")
    expect(result.fetch(:checks).map { _1.fetch(:status) }.uniq).to eq([ "pass" ])
    expect(result.fetch(:checks).map { _1.fetch(:name) }).to include(
      "runtime_environment",
      "row_level_security",
      "source_health",
      "telegram",
      "opentelemetry",
      "replay"
    )
    expect(JSON.generate(result)).not_to include("bot-secret", "-100123")
  end

  it "keeps running checks and reports stale acquisition evidence as not ready" do
    stale_health = class_double(
      Acquisition::SourceHealth,
      all: [
        {
          source_key: "dou",
          status: "succeeded",
          last_successful_at: now - 31.minutes,
          consecutive_failures: 0,
          observed_count: 2
        }
      ]
    )

    result = readiness(source_health: stale_health).call
    health = result.fetch(:checks).find { _1.fetch(:name) == "source_health" }
    replay_check = result.fetch(:checks).find { _1.fetch(:name) == "replay" }

    expect(result.fetch(:status)).to eq("not_ready")
    expect(health).to include(status: "fail")
    expect(health.dig(:error, :message)).to include("dou is stale")
    expect(replay_check).to include(status: "pass")
  end

  it "fails when a critical Phase 0 workspace table loses forced RLS" do
    broken_rows = rls_rows.map(&:dup)
    broken_rows.first["rls_forced"] = false
    broken_connection = FakePhase0Connection.new(rows: broken_rows)

    result = readiness(connection: -> { broken_connection }).call
    rls = result.fetch(:checks).find { _1.fetch(:name) == "row_level_security" }

    expect(result.fetch(:status)).to eq("not_ready")
    expect(rls).to include(status: "fail")
    expect(rls.dig(:error, :message)).to include("RLS/policy not enforced")
  end
end
