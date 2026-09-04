# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::McpOauthGrantAdmin do
  let!(:workspace) { Organization.create!(name: "Agent access", slug: "agent-access") }
  let!(:admin_user) do
    User.create!(
      name: "Grant Admin",
      email: "grant-admin@example.com",
      password: "Password12345!",
      verified: true
    )
  end
  let!(:recruiter_user) do
    User.create!(
      name: "Grant Recruiter",
      email: "grant-recruiter@example.com",
      password: "Password12345!",
      verified: true
    )
  end
  let!(:admin) { Membership.create!(user: admin_user, organization: workspace, role: "workspace_admin") }
  let!(:recruiter) { Membership.create!(user: recruiter_user, organization: workspace, role: "recruiter") }

  def create_membership_grant(capabilities: %w[read:openings submit:openings])
    Integration::McpOauthGrantRegistry.create_membership_grant(
      workspace_id: workspace.typed_id,
      membership_id: recruiter.typed_id,
      managed_by_membership_id: admin.typed_id,
      issuer: "https://auth.example.test/issuer",
      subject: "external-recruiter",
      client_id: "chatgpt-client",
      credential: "mcp-oauth:chatgpt",
      capabilities:,
      executor: "agent:chatgpt",
      client: "chatgpt"
    )
  end

  it "projects stored, workspace, and effective authorization for a membership grant" do
    grant = create_membership_grant

    snapshot = described_class.list_grants(
      workspace_id: workspace.typed_id,
      managed_by_membership_id: admin.typed_id
    ).sole

    expect(snapshot).to include(
      "id" => grant.fetch("id"),
      "authorization_kind" => "workspace_membership",
      "status" => "active",
      "capabilities" => %w[read:openings submit:openings],
      "workspace_capabilities" => Integration::Mcp::WorkspaceGrantPolicy::WORKSPACE_WIDE_CAPABILITIES,
      "effective_capabilities" => %w[read:openings submit:openings]
    )
    expect(snapshot.fetch("membership")).to include(
      "id" => recruiter.typed_id,
      "user_id" => recruiter_user.typed_id,
      "role" => "recruiter",
      "active" => true
    )

    recruiter.update!(active: false)

    blocked = described_class.list_grants(
      workspace_id: workspace.typed_id,
      managed_by_membership_id: admin.typed_id
    ).sole
    expect(blocked.fetch("status")).to eq("blocked")
    expect(blocked.fetch("workspace_capabilities")).to be_empty
    expect(blocked.fetch("effective_capabilities")).to be_empty
  end

  it "requires an active workspace admin to inspect grants" do
    create_membership_grant

    expect do
      described_class.list_grants(
        workspace_id: workspace.typed_id,
        managed_by_membership_id: recruiter.typed_id
      )
    end.to raise_error(
      described_class::Unauthorized,
      "workspace membership may not administer MCP OAuth grants"
    )
  end

  it "updates, revokes, and restores through the audited admin boundary" do
    grant = create_membership_grant(capabilities: %w[read:openings])

    described_class.update_capabilities(
      workspace_id: workspace.typed_id,
      grant_id: grant.fetch("id"),
      capabilities: %w[read:matches read:openings],
      managed_by_membership_id: admin.typed_id
    )
    described_class.revoke_grant(
      workspace_id: workspace.typed_id,
      grant_id: grant.fetch("id"),
      managed_by_membership_id: admin.typed_id,
      reason: "agent retired"
    )

    revoked = described_class.list_grants(
      workspace_id: workspace.typed_id,
      managed_by_membership_id: admin.typed_id
    ).sole
    expect(revoked.fetch("status")).to eq("revoked")
    expect(revoked.fetch("effective_capabilities")).to be_empty
    expect(revoked.fetch("revoke_reason")).to eq("agent retired")

    described_class.restore_grant(
      workspace_id: workspace.typed_id,
      grant_id: grant.fetch("id"),
      managed_by_membership_id: admin.typed_id
    )

    restored = described_class.list_grants(
      workspace_id: workspace.typed_id,
      managed_by_membership_id: admin.typed_id
    ).sole
    expect(restored.fetch("status")).to eq("active")
    expect(restored.fetch("capabilities")).to eq(%w[read:matches read:openings])

    history = Integration::McpOauthGrantRegistry.grant_history(
      workspace_id: workspace.typed_id,
      grant_id: grant.fetch("id")
    )
    expect(history.map { _1.fetch("action") }).to eq(
      %w[created capabilities_updated revoked restored]
    )
    expect(history.map { _1.fetch("managed_by") }.uniq).to eq([ admin.typed_id ])
  end

  it "shows service principals without pretending they are workspace-role constrained" do
    Integration::McpOauthGrantRegistry.create_grant(
      workspace_id: workspace.typed_id,
      issuer: "https://auth.example.test/issuer",
      subject: "automation-service",
      client_id: "automation-client",
      principal: "service:automation",
      credential: "mcp-oauth:automation",
      capabilities: %w[read:openings read:matches],
      managed_by: "migration:bootstrap",
      actor: "service:automation",
      executor: "agent:automation",
      client: "automation"
    )

    snapshot = described_class.list_grants(
      workspace_id: workspace.typed_id,
      managed_by_membership_id: admin.typed_id
    ).sole

    expect(snapshot).to include(
      "authorization_kind" => "service_principal",
      "status" => "active",
      "workspace_capabilities" => nil,
      "effective_capabilities" => %w[read:matches read:openings]
    )
    expect(snapshot.fetch("membership")).to be_nil
  end
end
