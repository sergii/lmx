# frozen_string_literal: true

require "rails_helper"

RSpec.describe Platform::Reliability::CommandExecutor do
  let(:connection) { ActiveRecord::Base.connection }
  let(:workspace_uuid) { SecureRandom.uuid }
  let(:command_id) { "command-#{SecureRandom.uuid}" }
  let(:idempotency_key) { "idem-#{SecureRandom.uuid}" }

  around do |example|
    previous = connection.select_value("SELECT current_setting('app.current_organization', true)")
    connection.select_value(
      "SELECT set_config('app.current_organization', #{connection.quote(workspace_uuid)}, false)"
    )
    example.run
  ensure
    if previous.present?
      connection.select_value(
        "SELECT set_config('app.current_organization', #{connection.quote(previous)}, false)"
      )
    else
      connection.execute("RESET app.current_organization")
    end
  end

  before do
    Platform::Reliability::Api.receive_command(
      message_id: "message-#{SecureRandom.uuid}",
      command_id:,
      idempotency_key:,
      command_name: "matches.assess",
      interface: "mcp",
      client: "chatgpt",
      principal: "user:serhii",
      credential: "credential:test",
      actor: "human:serhii",
      executor: "agent:chatgpt",
      payload: { candidate_id: "candidate-test" }
    )
  end

  it "executes a command once and reconstructs the prior result on retry" do
    calls = 0

    first = described_class.call(command_id:) do
      calls += 1
      { assessment_id: "match_assessment-test" }
    end
    replay = described_class.call(command_id:) do
      calls += 1
      raise "replay must not execute the command block"
    end

    expect(calls).to eq(1)
    expect(first.fetch(:replayed)).to be(false)
    expect(replay.fetch(:replayed)).to be(true)
    expect(replay.fetch(:result)).to eq("assessment_id" => "match_assessment-test")
    expect(replay.dig(:command, :attempt_count)).to eq(1)
  end

  it "rolls back domain effects and persists a retryable failure record" do
    expect do
      described_class.call(command_id:) do
        Platform::Reliability::Api.append_domain_event(
          event_type: "test.command.effect",
          aggregate_type: "test",
          aggregate_id: "test-aggregate",
          expected_aggregate_version: 0,
          data: { changed: true }
        )
        raise "processor failed"
      end
    end.to raise_error(RuntimeError, "processor failed")

    expect(Platform::DomainEvent.count).to eq(0)
    failed = Platform::Reliability::Api.fetch_command(command_id:)
    expect(failed.fetch(:status)).to eq("failed")
    expect(failed.fetch(:attempt_count)).to eq(1)
    expect(failed.fetch(:processing_error)).to include(
      "error_class" => "RuntimeError",
      "message" => "processor failed"
    )
  end
end
