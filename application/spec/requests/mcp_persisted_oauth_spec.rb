# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MCP persisted OAuth grants", type: :request do
  let!(:workspace) { Organization.create!(name: "MCP persisted OAuth", slug: "mcp-persisted-oauth") }
  let(:claims) do
    Integration::Mcp::OauthIntrospectionClient::Claims.new(
      issuer: "https://auth.example.test/issuer",
      subject: "external-user-123",
      client_id: "chatgpt-client",
      scopes: %w[read:openings submit:openings],
      audiences: [ "https://www.example.com/mcp" ],
      expires_at: Time.now + 300
    )
  end

  around do |example|
    keys = %w[
      LMX_MCP_HTTP_CREDENTIALS
      LMX_MCP_HTTP_ALLOWED_HOSTS
      LMX_MCP_HTTP_ALLOWED_ORIGINS
      LMX_MCP_OAUTH_RESOURCE
      LMX_MCP_OAUTH_AUTHORIZATION_SERVERS
      LMX_MCP_OAUTH_SCOPES
      LMX_MCP_OAUTH_RESOURCE_NAME
      LMX_MCP_OAUTH_INTROSPECTION_ENDPOINT
      LMX_MCP_OAUTH_INTROSPECTION_CLIENT_ID
      LMX_MCP_OAUTH_INTROSPECTION_CLIENT_SECRET
      LMX_MCP_OAUTH_GRANTS
    ]
    previous = keys.to_h { |key| [ key, ENV[key] ] }

    ENV.delete("LMX_MCP_HTTP_CREDENTIALS")
    ENV.delete("LMX_MCP_OAUTH_GRANTS")
    ENV["LMX_MCP_HTTP_ALLOWED_HOSTS"] = "www.example.com"
    ENV["LMX_MCP_HTTP_ALLOWED_ORIGINS"] = ""
    ENV["LMX_MCP_OAUTH_RESOURCE"] = "https://www.example.com/mcp"
    ENV["LMX_MCP_OAUTH_AUTHORIZATION_SERVERS"] = "https://auth.example.test/issuer"
    ENV["LMX_MCP_OAUTH_SCOPES"] = "read:openings submit:openings"
    ENV["LMX_MCP_OAUTH_RESOURCE_NAME"] = "LMX MCP Test"
    ENV["LMX_MCP_OAUTH_INTROSPECTION_ENDPOINT"] = "https://auth.example.test/oauth2/introspect"
    ENV["LMX_MCP_OAUTH_INTROSPECTION_CLIENT_ID"] = "lmx-resource-server"
    ENV["LMX_MCP_OAUTH_INTROSPECTION_CLIENT_SECRET"] = "resource-server-secret"

    example.run
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  def modern_meta
    {
      Integration::Mcp::Server::PROTOCOL_VERSION_META_KEY => Integration::Mcp::Server::MODERN_PROTOCOL_VERSION,
      Integration::Mcp::Server::CLIENT_CAPABILITIES_META_KEY => {},
      "io.modelcontextprotocol/clientInfo" => { "name" => "Persisted OAuth spec", "version" => "1" }
    }
  end

  def headers
    {
      "Authorization" => "Bearer external-oauth-token",
      "Content-Type" => "application/json",
      "MCP-Protocol-Version" => Integration::Mcp::Server::MODERN_PROTOCOL_VERSION,
      "Mcp-Method" => "server/discover"
    }
  end

  def body
    JSON.generate(
      jsonrpc: "2.0",
      id: "discover-persisted-oauth",
      method: "server/discover",
      params: { _meta: modern_meta }
    )
  end

  def persist_grant
    Integration::McpOauthGrantRegistry.create_grant(
      workspace_id: workspace.typed_id,
      issuer: claims.issuer,
      subject: claims.subject,
      client_id: claims.client_id,
      principal: "user:serhii",
      credential: "mcp-oauth:chatgpt",
      actor: "human:serhii",
      executor: "agent:chatgpt",
      client: "chatgpt",
      capabilities: %w[read:openings],
      managed_by: "user:admin"
    )
  end

  before do
    verifier = instance_double(Integration::Mcp::OauthIntrospectionClient, verify: claims)
    allow(Integration::Mcp::OauthIntrospectionClient).to receive(:new).and_return(verifier)
  end

  it "accepts an introspected token through a persisted local grant" do
    persist_grant

    post "/mcp", params: body, headers:

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("result", "supportedVersions")).to eq([ "2026-07-28" ])
  end

  it "rejects the same token immediately after the persisted grant is revoked" do
    grant = persist_grant
    Integration::McpOauthGrantRegistry.revoke_grant(
      workspace_id: workspace.typed_id,
      grant_id: grant.fetch("id"),
      managed_by: "user:security",
      reason: "access removed"
    )

    post "/mcp", params: body, headers:

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body).to eq("error" => "unauthorized")
  end
end
