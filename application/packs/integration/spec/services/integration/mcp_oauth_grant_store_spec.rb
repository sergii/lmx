# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::Mcp::OauthGrantStore do
  let(:serialized) do
    JSON.generate(
      [
        {
          issuer: "https://auth.example.test/issuer",
          subject: "external-user-123",
          client_id: "chatgpt-client",
          workspace_id: "org_01oauth",
          principal: "user:serhii",
          credential: "mcp-oauth:chatgpt",
          actor: "human:serhii",
          executor: "agent:chatgpt",
          client: "chatgpt",
          capabilities: %w[read:openings submit:openings assess:matches]
        }
      ]
    )
  end

  subject(:store) { described_class.new(serialized:) }

  def claims(scopes:)
    Integration::Mcp::OauthIntrospectionClient::Claims.new(
      issuer: "https://auth.example.test/issuer",
      subject: "external-user-123",
      client_id: "chatgpt-client",
      scopes:,
      audiences: [ "https://lmx.example.test/mcp" ],
      expires_at: Time.now + 300
    )
  end

  it "maps external subject/client identity to trusted local workspace identity" do
    identity = store.resolve(claims(scopes: %w[read:openings submit:openings]))

    expect(identity).to be_a(Integration::Mcp::RuntimeIdentity)
    expect(identity.workspace_id).to eq("org_01oauth")
    expect(identity.principal).to eq("user:serhii")
    expect(identity.credential).to eq("mcp-oauth:chatgpt")
    expect(identity.actor).to eq("human:serhii")
    expect(identity.executor).to eq("agent:chatgpt")
    expect(identity.client).to eq("chatgpt")
  end

  it "intersects verified OAuth scopes with server-side Integration capabilities" do
    identity = store.resolve(claims(scopes: %w[read:openings unknown:scope]))

    expect(identity.capabilities).to eq([ "read:openings" ])
  end

  it "never lets token scopes expand the server-side grant" do
    identity = store.resolve(
      claims(scopes: %w[read:openings submit:openings assess:matches admin:everything])
    )

    expect(identity.capabilities).to contain_exactly(
      "read:openings",
      "submit:openings",
      "assess:matches"
    )
  end

  it "returns nil when the token identity has no exact server-side mapping" do
    unmatched = Integration::Mcp::OauthIntrospectionClient::Claims.new(
      issuer: "https://auth.example.test/issuer",
      subject: "someone-else",
      client_id: "chatgpt-client",
      scopes: [ "read:openings" ],
      audiences: [ "https://lmx.example.test/mcp" ],
      expires_at: Time.now + 300
    )

    expect(store.resolve(unmatched)).to be_nil
  end

  it "returns nil when token scope and local capabilities have no overlap" do
    expect(store.resolve(claims(scopes: [ "read:candidates" ]))).to be_nil
  end

  it "rejects duplicate issuer subject client mappings" do
    duplicate = JSON.parse(serialized)
    duplicate << duplicate.first.merge("credential" => "mcp-oauth:duplicate")

    expect { described_class.new(serialized: JSON.generate(duplicate)) }
      .to raise_error(described_class::ConfigurationError, /mappings must be unique/)
  end
end
