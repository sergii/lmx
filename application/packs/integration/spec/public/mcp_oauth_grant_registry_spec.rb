# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::McpOauthGrantRegistry do
  let!(:workspace) { Organization.create!(name: "MCP OAuth workspace", slug: "mcp-oauth-workspace") }
  let!(:other_workspace) { Organization.create!(name: "Other MCP OAuth workspace", slug: "other-mcp-oauth-workspace") }

  def create_grant(**overrides)
    described_class.create_grant(
      workspace_id: workspace.typed_id,
      issuer: "https://auth.example.test/issuer",
      subject: "external-user-123",
      client_id: "chatgpt-client",
      principal: "user:serhii",
      credential: "mcp-oauth:chatgpt",
      capabilities: %w[read:openings submit:openings],
      managed_by: "user:admin",
      actor: "human:serhii",
      executor: "agent:chatgpt",
      client: "chatgpt",
      **overrides
    )
  end

  it "persists, audits, revokes, and restores a workspace grant" do
    created = create_grant

    expect(created.fetch("workspace_id")).to eq(workspace.typed_id)
    expect(created.fetch("capabilities")).to eq(%w[read:openings submit:openings])
    expect(created.fetch("revoked_at")).to be_nil
    expect(described_class.list_grants(workspace_id: workspace.typed_id)).to eq([ created ])

    updated = described_class.update_capabilities(
      workspace_id: workspace.typed_id,
      grant_id: created.fetch("id"),
      capabilities: %w[read:openings read:matches],
      managed_by: "user:admin"
    )
    expect(updated.fetch("capabilities")).to eq(%w[read:matches read:openings])

    revoked = described_class.revoke_grant(
      workspace_id: workspace.typed_id,
      grant_id: created.fetch("id"),
      managed_by: "user:security",
      reason: "device retired",
      revoked_at: Time.utc(2026, 9, 4, 20, 30, 0)
    )
    expect(revoked.fetch("revoked_by")).to eq("user:security")
    expect(revoked.fetch("revoke_reason")).to eq("device retired")
    expect(described_class.list_grants(workspace_id: workspace.typed_id)).to be_empty
    expect(
      described_class.list_grants(workspace_id: workspace.typed_id, include_revoked: true).one?
    ).to be(true)

    restored = described_class.restore_grant(
      workspace_id: workspace.typed_id,
      grant_id: created.fetch("id"),
      managed_by: "user:security"
    )
    expect(restored.fetch("revoked_at")).to be_nil

    history = described_class.grant_history(
      workspace_id: workspace.typed_id,
      grant_id: created.fetch("id")
    )
    expect(history.map { _1.fetch("action") }).to eq(
      %w[created capabilities_updated revoked restored]
    )
    expect(history.map { _1.fetch("managed_by") }).to eq(
      %w[user:admin user:admin user:security user:security]
    )
  end

  it "does not expose grants through another workspace" do
    created = create_grant

    expect do
      described_class.grant_history(
        workspace_id: other_workspace.typed_id,
        grant_id: created.fetch("id")
      )
    end.to raise_error(described_class::NotFound, "OAuth grant not found in workspace")
  end

  it "rejects ambiguous external identities across workspaces" do
    create_grant

    expect do
      create_grant(
        workspace_id: other_workspace.typed_id,
        credential: "mcp-oauth:other"
      )
    end.to raise_error(described_class::Conflict, "OAuth grant external identity or credential already exists")
  end
end
