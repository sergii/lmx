# frozen_string_literal: true

require "rails_helper"

RSpec.describe Platform::Reliability::Api do
  let(:connection) { ActiveRecord::Base.connection }
  let(:workspace_uuid) { SecureRandom.uuid }
  let(:command_attributes) do
    {
      message_id: "delivery-1",
      command_id: "command-1",
      idempotency_key: "idempotency-1",
      command_name: "matches.assess",
      interface: "mcp",
      client: "chatgpt",
      principal: "user:serhii",
      credential: "credential:opaque",
      actor: "human:serhii",
      executor: "agent:chatgpt",
      correlation_id: "correlation-1",
      payload: { candidate_id: "candidate_opaque", opening_id: "opening_opaque" }
    }
  end

  around do |example|
    previous = connection.select_value("SELECT current_setting('app.current_organization', true)")
    set_workspace(workspace_uuid)
    example.run
  ensure
    restore_workspace(previous)
  end

  it "deduplicates a retried command and reconstructs the prior result" do
    received = described_class.receive_command(**command_attributes)
    started = described_class.start_command(command_id: "command-1")
    completed = described_class.complete_command(
      command_id: "command-1",
      result: { assessment_id: "match_assessment_opaque", accepted: true }
    )
    duplicate = described_class.receive_command(
      **command_attributes.merge(message_id: "delivery-2")
    )

    expect(received.fetch(:duplicate)).to be(false)
    expect(started).to include(status: "processing", attempt_count: 1)
    expect(completed).to include(
      status: "succeeded",
      result: { "accepted" => true, "assessment_id" => "match_assessment_opaque" }
    )
    expect(duplicate.fetch(:duplicate)).to be(true)
    expect(duplicate.dig(:command, :result)).to eq(completed.fetch(:result))
    expect(Platform::InboxMessage.count).to eq(1)
  end

  it "uses canonical JSON ordering for idempotency digests" do
    described_class.receive_command(
      **command_attributes.merge(payload: { opening_id: "opening_opaque", candidate_id: "candidate_opaque" })
    )

    duplicate = described_class.receive_command(
      **command_attributes.merge(
        message_id: "delivery-2",
        payload: { candidate_id: "candidate_opaque", opening_id: "opening_opaque" }
      )
    )

    expect(duplicate.fetch(:duplicate)).to be(true)
    expect(Platform::InboxMessage.count).to eq(1)
  end

  it "rejects reuse of a command identity for a different payload" do
    described_class.receive_command(**command_attributes)

    expect do
      described_class.receive_command(
        **command_attributes.merge(
          message_id: "delivery-2",
          payload: { candidate_id: "different_candidate", opening_id: "opening_opaque" }
        )
      )
    end.to raise_error(described_class::IdempotencyConflict)
  end

  it "allocates aggregate versions optimistically and appends Outbox messages atomically" do
    change = described_class.append_domain_event(
      event_type: "match_assessment.recorded",
      aggregate_type: "MatchAssessment",
      aggregate_id: "match_assessment_opaque",
      expected_aggregate_version: 0,
      command_id: "command-1",
      idempotency_key: "idempotency-1",
      principal: "user:serhii",
      actor: "human:serhii",
      executor: "agent:chatgpt",
      interface: "mcp",
      client: "chatgpt",
      evidence_references: [ "candidate_profile_version_opaque", "opening_opaque" ],
      data: { assessment_id: "match_assessment_opaque" },
      outbox_messages: [
        {
          message_type: "lmx.match_assessment.recorded",
          message_version: 1,
          destination: "integration",
          payload: { assessment_id: "match_assessment_opaque" }
        }
      ]
    )

    expect(change.dig(:event, :aggregate_version)).to eq(1)
    expect(change.dig(:event, :command_id)).to eq("command-1")
    expect(change.fetch(:outbox).one?).to be(true)
    expect(change.dig(:outbox, 0, :status)).to eq("pending")
    expect(change.dig(:outbox, 0, :domain_event_id)).to eq(change.dig(:event, :id))
    expect(Platform::DomainEvent.count).to eq(1)
    expect(Platform::OutboxMessage.count).to eq(1)

    expect do
      described_class.append_domain_event(
        event_type: "match_assessment.recorded",
        aggregate_type: "MatchAssessment",
        aggregate_id: "match_assessment_opaque",
        expected_aggregate_version: 0,
        data: { assessment_id: "match_assessment_opaque" }
      )
    end.to raise_error(described_class::ConcurrencyConflict, /current version is 1/)
  end

  it "leases Outbox work and reclaims a stale publishing claim after a worker crash" do
    now = Time.zone.parse("2026-09-02 18:00:00")
    change = described_class.append_domain_event(
      event_type: "job_posting.updated",
      aggregate_type: "JobPosting",
      aggregate_id: "job_posting_opaque",
      expected_aggregate_version: 0,
      occurred_at: now,
      data: { changed: true },
      outbox_messages: [
        {
          message_type: "lmx.posting.changed",
          payload: { posting_id: "job_posting_opaque" }
        }
      ]
    )

    first_claim = described_class.claim_outbox(limit: 10, at: now, lease_timeout: 5.minutes)
    early_retry = described_class.claim_outbox(limit: 10, at: now + 4.minutes, lease_timeout: 5.minutes)
    reclaimed = described_class.claim_outbox(limit: 10, at: now + 6.minutes, lease_timeout: 5.minutes)
    published = described_class.mark_outbox_published(
      message_id: change.dig(:outbox, 0, :id),
      published_at: now + 7.minutes
    )

    expect(first_claim.one?).to be(true)
    expect(first_claim.first).to include(
      status: "publishing",
      attempt_count: 1,
      publishing_started_at: now
    )
    expect(early_retry).to be_empty
    expect(reclaimed.one?).to be(true)
    expect(reclaimed.first).to include(
      status: "publishing",
      attempt_count: 2,
      publishing_started_at: now + 6.minutes
    )
    expect(published).to include(status: "published", attempt_count: 2)
    expect(published.fetch(:publishing_started_at)).to be_nil
    expect(published.fetch(:published_at)).to eq(now + 7.minutes)
  end

  it "requires an explicit database workspace scope" do
    connection.execute("RESET app.current_organization")

    expect do
      described_class.receive_command(**command_attributes)
    end.to raise_error(described_class::MissingWorkspace)
  ensure
    set_workspace(workspace_uuid)
  end

  it "returns frozen public snapshots instead of persistence models" do
    result = described_class.receive_command(**command_attributes)

    expect(result).to be_frozen
    expect(result.fetch(:command)).to be_frozen
    expect(result.dig(:command, :id)).to start_with("inbox_")
    expect(result.dig(:command, :workspace_id)).to start_with("org_")
  end

  private

  def set_workspace(uuid)
    connection.execute(
      "SELECT set_config('app.current_organization', #{connection.quote(uuid.to_s)}, false)"
    )
  end

  def restore_workspace(previous)
    if previous.present?
      set_workspace(previous)
    else
      connection.execute("RESET app.current_organization")
    end
  end
end
