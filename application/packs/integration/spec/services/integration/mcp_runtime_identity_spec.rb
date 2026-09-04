# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::Mcp::RuntimeIdentity do
  subject(:identity) do
    described_class.new(
      workspace_id: "org_01example",
      principal: "user:serhii",
      credential: "credential:local",
      actor: "human:serhii",
      executor: "agent:local",
      client: "codex",
      capabilities: [ "read:openings", "submit:openings", "read:openings" ],
      runtime_id: "runtime-1"
    )
  end

  it "builds immutable server-side capability evidence for the exact security identity" do
    context = identity.read_context(request_id: "request-1")
    grant = identity.credential_source.resolve(context)

    expect(grant).to eq(
      workspace_id: "org_01example",
      principal: "user:serhii",
      credential: "credential:local",
      capabilities: [ "read:openings", "submit:openings" ]
    )
    expect(grant).to be_frozen
    expect(identity.capabilities).to be_frozen
  end

  it "does not resolve a grant for a different trusted context" do
    context = Integration::Read::Context.new(
      workspace_id: "org_other",
      principal: identity.principal,
      credential: identity.credential,
      actor: identity.actor,
      executor: identity.executor,
      interface: "mcp",
      client: identity.client
    )

    expect(identity.credential_source.resolve(context)).to be_nil
  end

  it "derives stable but tool-specific fallback command identities within one runtime" do
    first = identity.command_context(request_id: 42, tool_name: "openings.submit")
    replay = identity.command_context(request_id: 42, tool_name: "openings.submit")
    other = identity.command_context(request_id: 42, tool_name: "matches.assess")

    expect(replay.command_id).to eq(first.command_id)
    expect(replay.idempotency_key).to eq(first.idempotency_key)
    expect(other.command_id).not_to eq(first.command_id)
    expect(first.interface).to eq("mcp")
    expect(first.causation_id).to eq("42")
  end

  it "uses a client idempotency key as the durable retry identity across JSON-RPC request ids" do
    first = identity.command_context(
      request_id: "rpc-1",
      tool_name: "openings.submit",
      idempotency_key: "submission-123"
    )
    retry_context = identity.command_context(
      request_id: "rpc-99",
      tool_name: "openings.submit",
      idempotency_key: "submission-123"
    )

    expect(retry_context.command_id).to eq(first.command_id)
    expect(retry_context.idempotency_key).to eq(first.idempotency_key)
  end

  it "scopes request-id fallback identities to one runtime session" do
    other_runtime = described_class.new(
      workspace_id: identity.workspace_id,
      principal: identity.principal,
      credential: identity.credential,
      actor: identity.actor,
      executor: identity.executor,
      client: identity.client,
      capabilities: identity.capabilities,
      runtime_id: "runtime-2"
    )

    first = identity.command_context(request_id: 42, tool_name: "openings.submit")
    later_session = other_runtime.command_context(request_id: 42, tool_name: "openings.submit")

    expect(later_session.command_id).not_to eq(first.command_id)
  end
end
