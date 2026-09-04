# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Agent access settings", type: :request do
  let!(:organization) { Organization.create!(name: "Agent access workspace", slug: "agent-access-workspace") }
  let!(:admin_user) do
    User.create!(
      name: "Workspace Admin",
      email: "agent-access-admin@example.com",
      password: "Password12345!",
      verified: true
    )
  end
  let!(:recruiter_user) do
    User.create!(
      name: "MCP Recruiter",
      email: "agent-access-recruiter@example.com",
      password: "Password12345!",
      verified: true
    )
  end
  let!(:admin) { Membership.create!(user: admin_user, organization:, role: "workspace_admin") }
  let!(:recruiter) { Membership.create!(user: recruiter_user, organization:, role: "recruiter") }
  let!(:grant) do
    Integration::McpOauthGrantRegistry.create_membership_grant(
      workspace_id: organization.typed_id,
      membership_id: recruiter.typed_id,
      managed_by_membership_id: admin.typed_id,
      issuer: "https://auth.example.test/issuer",
      subject: "external-recruiter",
      client_id: "chatgpt-client",
      credential: "mcp-oauth:chatgpt-admin-surface",
      capabilities: %w[read:openings submit:openings],
      executor: "agent:chatgpt",
      client: "chatgpt"
    )
  end

  it "lets a workspace admin inspect and manage persisted MCP OAuth access" do
    sign_in admin_user

    get settings_agent_access_path

    expect(response).to have_http_status(:success)
    expect(inertia_component).to eq("settings/agent_access/show")
    expect(response.body).to include(
      grant.fetch("id"),
      '"authorization_kind":"workspace_membership"',
      '"status":"active"',
      '"effective_capabilities":["read:openings","submit:openings"]'
    )

    patch "/settings/agent-access/grants/#{grant.fetch("id")}/capabilities",
      params: { capabilities: %w[read:openings read:matches] }

    expect(response).to redirect_to(settings_agent_access_path)
    stored = Integration::McpOauthGrantRegistry.list_grants(
      workspace_id: organization.typed_id,
      include_revoked: true
    ).sole
    expect(stored.fetch("capabilities")).to eq(%w[read:matches read:openings])

    post "/settings/agent-access/grants/#{grant.fetch("id")}/revoke",
      params: { reason: "ChatGPT workspace disconnected" }

    expect(response).to redirect_to(settings_agent_access_path)
    revoked = Integration::McpOauthGrantRegistry.list_grants(
      workspace_id: organization.typed_id,
      include_revoked: true
    ).sole
    expect(revoked.fetch("revoked_at")).to be_present
    expect(revoked.fetch("revoke_reason")).to eq("ChatGPT workspace disconnected")

    post "/settings/agent-access/grants/#{grant.fetch("id")}/restore"

    expect(response).to redirect_to(settings_agent_access_path)
    restored = Integration::McpOauthGrantRegistry.list_grants(
      workspace_id: organization.typed_id,
      include_revoked: true
    ).sole
    expect(restored.fetch("revoked_at")).to be_nil

    history = Integration::McpOauthGrantRegistry.grant_history(
      workspace_id: organization.typed_id,
      grant_id: grant.fetch("id")
    )
    expect(history.map { _1.fetch("action") }).to eq(
      %w[created capabilities_updated revoked restored]
    )
    expect(history.map { _1.fetch("managed_by") }.uniq).to eq([ admin.typed_id ])
  end

  it "hides the agent access control plane from non-admin members" do
    sign_in recruiter_user

    get settings_agent_access_path

    expect(response).to have_http_status(:not_found)
  end
end
