# frozen_string_literal: true

require "digest"
require "rails_helper"

RSpec.describe "OpenAI MCP HTTP compatibility", type: :request do
  let!(:workspace) { Organization.create!(name: "OpenAI MCP workspace", slug: "openai-mcp-workspace") }
  let(:token) { "openai-mcp-compat-token" }

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

    ENV["LMX_MCP_HTTP_CREDENTIALS"] = JSON.generate(
      [
        {
          token_sha256: Digest::SHA256.hexdigest(token),
          workspace_id: workspace.typed_id,
          principal: "user:openai-e2e",
          credential: "mcp-http:openai-e2e",
          actor: "human:openai-e2e",
          executor: "agent:openai-mcp",
          client: "openai-mcp",
          capabilities: %w[read:openings submit:openings]
        }
      ]
    )
    ENV["LMX_MCP_HTTP_ALLOWED_HOSTS"] = "www.example.com"
    ENV["LMX_MCP_HTTP_ALLOWED_ORIGINS"] = ""
    keys.grep(/LMX_MCP_OAUTH/).each { ENV.delete(_1) }

    example.run
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  def base_headers
    {
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json"
    }
  end

  def legacy_headers
    base_headers.merge("MCP-Protocol-Version" => "2025-11-25")
  end

  it "accepts the current OpenAI hosted MCP initialize, list, and call sequence without a server session" do
    post "/mcp",
      params: JSON.generate(
        jsonrpc: "2.0",
        id: 0,
        method: "initialize",
        params: {
          protocolVersion: "2025-11-25",
          capabilities: {},
          clientInfo: { name: "openai-mcp", version: "1.0.0" }
        }
      ),
      headers: base_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("result", "protocolVersion")).to eq("2025-11-25")
    expect(response.headers["Mcp-Session-Id"]).to be_nil

    post "/mcp",
      params: JSON.generate(
        jsonrpc: "2.0",
        method: "notifications/initialized",
        params: {}
      ),
      headers: legacy_headers

    expect(response).to have_http_status(:accepted)
    expect(response.body).to be_empty

    post "/mcp",
      params: JSON.generate(
        jsonrpc: "2.0",
        id: 0,
        method: "tools/list",
        params: {}
      ),
      headers: legacy_headers

    expect(response).to have_http_status(:ok)
    tools = response.parsed_body.dig("result", "tools")
    expect(tools.map { _1.fetch("name") }).to include("openings.search", "openings.submit")

    read_tool = tools.find { _1.fetch("name") == "openings.search" }
    expect(read_tool.fetch("annotations")).to include(
      "readOnlyHint" => true,
      "destructiveHint" => false,
      "openWorldHint" => false
    )

    write_tool = tools.find { _1.fetch("name") == "openings.submit" }
    expect(write_tool.dig("inputSchema", "required")).to include(
      Integration::Mcp::Server::IDEMPOTENCY_KEY_ARGUMENT
    )
    expect(write_tool.dig("annotations", "idempotentHint")).to be(true)

    post "/mcp",
      params: JSON.generate(
        jsonrpc: "2.0",
        id: 0,
        method: "tools/call",
        params: {
          name: "openings.search",
          arguments: {},
          _meta: { progressToken: "openai-client-signal" }
        }
      ),
      headers: legacy_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("result", "isError")).to be(false)
    expect(response.parsed_body.dig("result", "structuredContent", "data", "items")).to eq([])
  end
end
