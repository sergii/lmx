# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MCP OAuth pairing", type: :request do
  let!(:organization) { Organization.create!(name: "Pairing workspace", slug: "pairing-workspace") }
  let!(:admin_user) do
    User.create!(
      name: "Pairing Admin",
      email: "pairing-browser-admin@example.com",
      password: "Password12345!",
      verified: true
    )
  end
  let!(:recruiter_user) do
    User.create!(
      name: "Pairing Recruiter",
      email: "pairing-browser-recruiter@example.com",
      password: "Password12345!",
      verified: true
    )
  end
  let!(:admin) { Membership.create!(user: admin_user, organization:, role: "workspace_admin") }
  let!(:recruiter) { Membership.create!(user: recruiter_user, organization:, role: "recruiter") }
  let(:resource) { "https://www.example.com/mcp" }
  let(:claims) do
    Integration::Mcp::OauthIntrospectionClient::Claims.new(
      issuer: "https://auth.example.test/issuer",
      subject: "external-pairing-user",
      client_id: "https://client.example.test/chatgpt.json",
      scopes: %w[read:openings submit:openings],
      audiences: [ resource ],
      expires_at: Time.current + 10.minutes
    )
  end
  let(:pairing_token) { Integration::McpOauthPairing.issue(claims:, resource:).token }

  around do |example|
    keys = %w[
      LMX_MCP_OAUTH_RESOURCE
      LMX_MCP_OAUTH_AUTHORIZATION_SERVERS
      LMX_MCP_OAUTH_SCOPES
      LMX_MCP_OAUTH_RESOURCE_NAME
    ]
    previous = keys.to_h { |key| [ key, ENV[key] ] }

    ENV["LMX_MCP_OAUTH_RESOURCE"] = resource
    ENV["LMX_MCP_OAUTH_AUTHORIZATION_SERVERS"] = claims.issuer
    ENV["LMX_MCP_OAUTH_SCOPES"] = "read:openings submit:openings"
    ENV["LMX_MCP_OAUTH_RESOURCE_NAME"] = "LMX MCP Pairing Test"

    example.run
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  it "shows a verified pairing request to a workspace admin" do
    sign_in admin_user

    get settings_mcp_oauth_pairing_path(pairing_token:)

    expect(response).to have_http_status(:success)
    expect(inertia_component).to eq("settings/agent_access/pair")
    expect(response.body).to include(
      "external-pairing-user",
      "https://client.example.test/chatgpt.json",
      '"pairable_capabilities":["read:openings","submit:openings"]',
      "Pairing Recruiter"
    )
  end

  it "binds the external identity to the selected member and capabilities" do
    sign_in admin_user

    post settings_mcp_oauth_pairing_path,
      params: {
        pairing_token:,
        membership_id: recruiter.typed_id,
        capabilities: %w[read:openings]
      }

    expect(response).to redirect_to(settings_agent_access_path)

    grant = Integration::McpOauthGrantRegistry.list_grants(
      workspace_id: organization.typed_id,
      include_revoked: true
    ).sole
    expect(grant).to include(
      "issuer" => claims.issuer,
      "subject" => claims.subject,
      "client_id" => claims.client_id,
      "principal" => recruiter_user.typed_id,
      "capabilities" => %w[read:openings],
      "created_by" => admin.typed_id
    )

    history = Integration::McpOauthGrantRegistry.grant_history(
      workspace_id: organization.typed_id,
      grant_id: grant.fetch("id")
    )
    expect(history.map { _1.fetch("managed_by") }.uniq).to eq([ admin.typed_id ])
  end

  it "does not let approval expand beyond verified token scopes" do
    sign_in admin_user

    post settings_mcp_oauth_pairing_path,
      params: {
        pairing_token:,
        membership_id: recruiter.typed_id,
        capabilities: %w[read:candidates]
      }

    expect(response).to redirect_to(
      settings_mcp_oauth_pairing_path(pairing_token:)
    )
    expect(
      Integration::McpOauthGrantRegistry.list_grants(
        workspace_id: organization.typed_id,
        include_revoked: true
      )
    ).to be_empty
  end

  it "prevents a pairing ticket from creating a second mapping" do
    sign_in admin_user
    params = {
      pairing_token:,
      membership_id: recruiter.typed_id,
      capabilities: %w[read:openings]
    }

    post settings_mcp_oauth_pairing_path, params:
    expect(response).to redirect_to(settings_agent_access_path)

    post settings_mcp_oauth_pairing_path, params:
    expect(response).to redirect_to(settings_agent_access_path)
    expect(
      Integration::McpOauthGrantRegistry.list_grants(
        workspace_id: organization.typed_id,
        include_revoked: true
      ).size
    ).to eq(1)
  end

  it "hides pairing approval from non-admin workspace members" do
    sign_in recruiter_user

    get settings_mcp_oauth_pairing_path(pairing_token:)

    expect(response).to have_http_status(:not_found)
  end

  it "preserves a pairing link through sign in" do
    get settings_mcp_oauth_pairing_path(pairing_token:)

    expect(response).to redirect_to(sign_in_path)

    post sign_in_path,
      params: {
        email: admin_user.email,
        password: "Password12345!"
      }

    expect(response).to redirect_to(
      settings_mcp_oauth_pairing_path(pairing_token:)
    )
  end
end
