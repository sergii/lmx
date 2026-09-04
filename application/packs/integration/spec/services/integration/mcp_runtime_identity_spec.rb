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
      capabilities: [ "read:openings", "submit:openings", "read:openings" ]
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

  it "derives stable but tool-specific command identities from the JSON-RPC request id" do
    first = identity.command_context(request_id: 42, tool_name: "openings.submit")
    replay = identity.command_context(request_id: 42, tool_name: "openings.submit")
    other = identity.command_context(request_id: 42, tool_name: "matches.assess")

    expect(replay.command_id).to eq(first.command_id)
    expect(replay.idempotency_key).to eq(first.idempotency_key)
    expect(other.command_id).not_to eq(first.command_id)
    expect(first.interface).to eq("mcp")
    expect(first.causation_id).to eq("42")
  end
end
