# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::McpOAuthResourceMetadata do
  let(:environment) do
    {
      "LMX_MCP_OAUTH_RESOURCE" => "https://lmx.example.test/mcp",
      "LMX_MCP_OAUTH_AUTHORIZATION_SERVERS" => "https://auth.example.test/issuer",
      "LMX_MCP_OAUTH_SCOPES" => "read:openings submit:openings",
      "LMX_MCP_OAUTH_RESOURCE_NAME" => "LMX MCP Test"
    }
  end

  it "builds metadata from deployment configuration" do
    metadata = described_class.build(environment:)

    expect(metadata.to_h).to include(
      "resource" => "https://lmx.example.test/mcp",
      "authorization_servers" => [ "https://auth.example.test/issuer" ],
      "scopes_supported" => %w[read:openings submit:openings],
      "resource_name" => "LMX MCP Test"
    )
  end

  it "builds an RFC 9728 bearer challenge" do
    expect(described_class.challenge(environment:)).to eq(
      'Bearer realm="lmx-mcp", ' \
      'resource_metadata="https://lmx.example.test/.well-known/oauth-protected-resource/mcp", ' \
      'scope="read:openings submit:openings"'
    )
  end

  it "keeps the bootstrap bearer challenge when OAuth metadata is not configured" do
    expect(described_class.challenge(environment: {})).to eq('Bearer realm="lmx-mcp"')
  end

  it "fails closed on partial OAuth metadata configuration" do
    expect do
      described_class.build(
        environment: { "LMX_MCP_OAUTH_RESOURCE" => "https://lmx.example.test/mcp" }
      )
    end.to raise_error(described_class::ConfigurationError, /AUTHORIZATION_SERVERS/)
  end

  it "requires metadata to identify the actual public MCP resource" do
    expect do
      described_class.build(
        environment: environment.merge("LMX_MCP_OAUTH_RESOURCE" => "https://lmx.example.test/api")
      )
    end.to raise_error(described_class::ConfigurationError, /public \/mcp endpoint/)
  end
end
