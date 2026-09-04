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

  def create_user(name:, email:)
    User.create!(
      name:,
      email:,
      password: "Password12345!",
      verified: true
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

  it "creates a membership-bound grant only through an active workspace admin" do
    admin_user = create_user(name: "Grant Admin", email: "grant-admin@example.com")
    recruiter_user = create_user(name: "Grant Recruiter", email: "grant-recruiter@example.com")
    admin = Membership.create!(user: admin_user, organization: workspace, role: "workspace_admin")
    recruiter = Membership.create!(user: recruiter_user, organization: workspace, role: "recruiter")

    created = described_class.create_membership_grant(
      workspace_id: workspace.typed_id,
      membership_id: recruiter.typed_id,
      managed_by_membership_id: admin.typed_id,
      issuer: "https://auth.example.test/issuer",
      subject: "external-recruiter",
      client_id: "claude-client",
      credential: "mcp-oauth:claude-recruiter",
      capabilities: %w[read:openings submit:openings read:applications],
      executor: "agent:claude",
      client: "claude"
    )

    expect(created).to include(
      "principal" => recruiter_user.typed_id,
      "actor" => recruiter_user.typed_id,
      "created_by" => admin.typed_id,
      "capabilities" => %w[read:applications read:openings submit:openings]
    )

    history = described_class.grant_history(
      workspace_id: workspace.typed_id,
      grant_id: created.fetch("id")
    )
    expect(history.first.fetch("managed_by")).to eq(admin.typed_id)
  end

  it "rejects grant administration by a non-admin workspace member" do
    manager_user = create_user(name: "Recruiter Manager", email: "recruiter-manager@example.com")
    target_user = create_user(name: "Recruiter Target", email: "recruiter-target@example.com")
    manager = Membership.create!(user: manager_user, organization: workspace, role: "recruiter")
    target = Membership.create!(user: target_user, organization: workspace, role: "recruiter")

    expect do
      described_class.create_membership_grant(
        workspace_id: workspace.typed_id,
        membership_id: target.typed_id,
        managed_by_membership_id: manager.typed_id,
        issuer: "https://auth.example.test/issuer",
        subject: "external-target",
        client_id: "chatgpt-target",
        credential: "mcp-oauth:target",
        capabilities: %w[read:openings]
      )
    end.to raise_error(
      described_class::Unauthorized,
      "workspace membership may not administer MCP OAuth grants"
    )
  end

  it "rejects capabilities outside the target membership authorization" do
    admin_user = create_user(name: "Capability Admin", email: "capability-admin@example.com")
    client_user = create_user(name: "Client Member", email: "client-member@example.com")
    client_company = ClientCompany.create!(organization: workspace, name: "Client Company")
    admin = Membership.create!(user: admin_user, organization: workspace, role: "workspace_admin")
    client_member = Membership.create!(
      user: client_user,
      organization: workspace,
      role: "client_hiring_manager",
      client_company:
    )

    expect do
      described_class.create_membership_grant(
        workspace_id: workspace.typed_id,
        membership_id: client_member.typed_id,
        managed_by_membership_id: admin.typed_id,
        issuer: "https://auth.example.test/issuer",
        subject: "external-client",
        client_id: "client-mcp",
        credential: "mcp-oauth:client",
        capabilities: %w[read:openings]
      )
    end.to raise_error(
      described_class::Unauthorized,
      "requested capabilities exceed workspace membership authorization"
    )
  end

  it "rechecks target membership authorization before capability updates" do
    admin_user = create_user(name: "Update Admin", email: "update-admin@example.com")
    recruiter_user = create_user(name: "Update Recruiter", email: "update-recruiter@example.com")
    admin = Membership.create!(user: admin_user, organization: workspace, role: "workspace_admin")
    recruiter = Membership.create!(user: recruiter_user, organization: workspace, role: "recruiter")

    created = described_class.create_membership_grant(
      workspace_id: workspace.typed_id,
      membership_id: recruiter.typed_id,
      managed_by_membership_id: admin.typed_id,
      issuer: "https://auth.example.test/issuer",
      subject: "external-update-recruiter",
      client_id: "update-client",
      credential: "mcp-oauth:update",
      capabilities: %w[read:openings]
    )

    recruiter.update!(active: false)

    expect do
      described_class.update_membership_capabilities(
        workspace_id: workspace.typed_id,
        grant_id: created.fetch("id"),
        capabilities: %w[read:openings read:matches],
        managed_by_membership_id: admin.typed_id
      )
    end.to raise_error(
      described_class::Unauthorized,
      "requested capabilities exceed workspace membership authorization"
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
