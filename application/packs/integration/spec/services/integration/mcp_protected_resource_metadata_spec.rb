# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::Mcp::ProtectedResourceMetadata do
  subject(:metadata) do
    described_class.new(
      resource: "https://lmx.example.test/mcp",
      authorization_servers: [ "https://auth.example.test/issuer" ],
      scopes_supported: %w[submit:openings read:openings read:openings],
      resource_name: "LMX MCP"
    )
  end

  it "publishes RFC 9728 metadata for the exact MCP resource identifier" do
    expect(metadata.to_h).to eq(
      "resource" => "https://lmx.example.test/mcp",
      "authorization_servers" => [ "https://auth.example.test/issuer" ],
      "bearer_methods_supported" => [ "header" ],
      "scopes_supported" => %w[read:openings submit:openings],
      "resource_name" => "LMX MCP"
    )
  end

  it "derives the well-known URL by inserting the RFC 9728 suffix before the resource path" do
    expect(metadata.metadata_url).to eq(
      "https://lmx.example.test/.well-known/oauth-protected-resource/mcp"
    )
  end

  it "rejects non-HTTPS resource and authorization-server identifiers" do
    expect do
      described_class.new(
        resource: "http://lmx.example.test/mcp",
        authorization_servers: [ "https://auth.example.test" ]
      )
    end.to raise_error(ArgumentError, /absolute HTTPS URI/)

    expect do
      described_class.new(
        resource: "https://lmx.example.test/mcp",
        authorization_servers: [ "http://auth.example.test" ]
      )
    end.to raise_error(ArgumentError, /absolute HTTPS URI/)
  end

  it "rejects malformed OAuth scope tokens" do
    expect do
      described_class.new(
        resource: "https://lmx.example.test/mcp",
        authorization_servers: [ "https://auth.example.test" ],
        scopes_supported: [ "read openings" ]
      )
    end.to raise_error(ArgumentError, /scope tokens/)
  end
end
