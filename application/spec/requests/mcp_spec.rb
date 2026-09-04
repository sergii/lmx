# frozen_string_literal: true

require "digest"
require "rails_helper"

RSpec.describe "MCP HTTP endpoint", type: :request do
  let(:token) { "remote-mcp-test-token" }
  let(:credential_config) do
    JSON.generate(
      [
        {
          token_sha256: Digest::SHA256.hexdigest(token),
          workspace_id: "org_01mcphttp",
          principal: "user:serhii",
          credential: "mcp-http:test",
          actor: "human:serhii",
          executor: "agent:test-client",
          client: "test-client",
          capabilities: %w[read:openings read:candidates read:matches submit:openings assess:matches]
        }
      ]
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
    ]
    previous = keys.to_h { |key| [ key, ENV[key] ] }

    ENV["LMX_MCP_HTTP_CREDENTIALS"] = credential_config
    ENV["LMX_MCP_HTTP_ALLOWED_HOSTS"] = "www.example.com"
    ENV["LMX_MCP_HTTP_ALLOWED_ORIGINS"] = "https://client.example.test"
    %w[
      LMX_MCP_OAUTH_RESOURCE
      LMX_MCP_OAUTH_AUTHORIZATION_SERVERS
      LMX_MCP_OAUTH_SCOPES
      LMX_MCP_OAUTH_RESOURCE_NAME
    ].each { ENV.delete(_1) }

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
      "io.modelcontextprotocol/clientInfo" => { "name" => "Request spec", "version" => "1" }
    }
  end

  def mcp_headers(method:, name: nil, authorization: "Bearer #{token}")
    headers = {
      "Authorization" => authorization,
      "Content-Type" => "application/json",
      "MCP-Protocol-Version" => Integration::Mcp::Server::MODERN_PROTOCOL_VERSION,
      "Mcp-Method" => method
    }
    headers["Mcp-Name"] = name if name
    headers
  end

  def configure_oauth_metadata
    ENV["LMX_MCP_OAUTH_RESOURCE"] = "https://www.example.com/mcp"
    ENV["LMX_MCP_OAUTH_AUTHORIZATION_SERVERS"] = "https://auth.example.test/issuer"
    ENV["LMX_MCP_OAUTH_SCOPES"] = "read:openings submit:openings"
    ENV["LMX_MCP_OAUTH_RESOURCE_NAME"] = "LMX MCP Test"
  end

  it "serves authenticated modern discovery through POST /mcp" do
    body = {
      jsonrpc: "2.0",
      id: "discover-1",
      method: "server/discover",
      params: { _meta: modern_meta }
    }

    post "/mcp", params: JSON.generate(body), headers: mcp_headers(method: "server/discover")

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("result", "supportedVersions")).to eq([ "2026-07-28" ])
    expect(response.parsed_body.dig("result", "_meta", Integration::Mcp::Server::SERVER_INFO_META_KEY, "name")).to eq("lmx")
    expect(response.headers["Cache-Control"]).to eq("no-store")
  end

  it "returns an HTTP bearer challenge before MCP dispatch when authorization is missing" do
    body = {
      jsonrpc: "2.0",
      id: "discover-1",
      method: "server/discover",
      params: { _meta: modern_meta }
    }

    headers = mcp_headers(method: "server/discover", authorization: "")
    post "/mcp", params: JSON.generate(body), headers: headers

    expect(response).to have_http_status(:unauthorized)
    expect(response.headers["WWW-Authenticate"]).to eq('Bearer realm="lmx-mcp"')
    expect(response.parsed_body).to eq("error" => "unauthorized")
  end

  it "serves RFC 9728 protected resource metadata when OAuth discovery is configured" do
    configure_oauth_metadata

    get "/.well-known/oauth-protected-resource/mcp"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      "resource" => "https://www.example.com/mcp",
      "authorization_servers" => [ "https://auth.example.test/issuer" ],
      "bearer_methods_supported" => [ "header" ],
      "scopes_supported" => %w[read:openings submit:openings],
      "resource_name" => "LMX MCP Test"
    )
    expect(response.headers["Cache-Control"].split(", ")).to contain_exactly("public", "max-age=300")
  end

  it "returns 404 for protected resource metadata until OAuth discovery is configured" do
    get "/.well-known/oauth-protected-resource/mcp"

    expect(response).to have_http_status(:not_found)
  end

  it "advertises RFC 9728 resource metadata in the bearer challenge when configured" do
    configure_oauth_metadata
    body = {
      jsonrpc: "2.0",
      id: "discover-1",
      method: "server/discover",
      params: { _meta: modern_meta }
    }

    post "/mcp",
      params: JSON.generate(body),
      headers: mcp_headers(method: "server/discover", authorization: "")

    expect(response).to have_http_status(:unauthorized)
    expect(response.headers["WWW-Authenticate"]).to eq(
      'Bearer realm="lmx-mcp", ' \
      'resource_metadata="https://www.example.com/.well-known/oauth-protected-resource/mcp", ' \
      'scope="read:openings submit:openings"'
    )
  end

  it "returns the protocol header-mismatch error when a required modern header is absent" do
    body = {
      jsonrpc: "2.0",
      id: "list-1",
      method: "tools/list",
      params: { _meta: modern_meta }
    }
    headers = mcp_headers(method: "tools/list").except("Mcp-Method")

    post "/mcp", params: JSON.generate(body), headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body.dig("error", "code")).to eq(Integration::Mcp::Server::HEADER_MISMATCH)
  end

  it "requires an explicit durable idempotency key for remote write tools" do
    body = {
      jsonrpc: "2.0",
      id: "submit-1",
      method: "tools/call",
      params: {
        name: "openings.submit",
        arguments: { title: "Senior Ruby Engineer" },
        _meta: modern_meta
      }
    }

    post "/mcp",
      params: JSON.generate(body),
      headers: mcp_headers(method: "tools/call", name: "openings.submit")

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body.dig("error", "code")).to eq(Integration::Mcp::Server::INVALID_PARAMS)
    expect(response.parsed_body.dig("error", "message")).to include(Integration::Mcp::Server::IDEMPOTENCY_KEY_META_KEY)
  end

  it "rejects an unexpected browser Origin before MCP dispatch" do
    body = {
      jsonrpc: "2.0",
      id: "list-1",
      method: "tools/list",
      params: { _meta: modern_meta }
    }
    headers = mcp_headers(method: "tools/list").merge("Origin" => "https://evil.example.test")

    post "/mcp", params: JSON.generate(body), headers: headers

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body).to eq("error" => "forbidden_origin")
  end
end
