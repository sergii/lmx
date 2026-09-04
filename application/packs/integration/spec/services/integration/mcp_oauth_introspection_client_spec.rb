# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::Mcp::OauthIntrospectionClient do
  let(:now) { Time.utc(2026, 9, 4, 20, 0, 0) }
  let(:payload) do
    {
      active: true,
      iss: "https://auth.example.test/issuer",
      sub: "external-user-123",
      client_id: "chatgpt-client",
      scope: "read:openings submit:openings",
      aud: [ "https://lmx.example.test/mcp" ],
      exp: now.to_i + 300
    }
  end
  let(:requester) { ->(_token) { [ 200, JSON.generate(payload) ] } }

  subject(:client) do
    described_class.new(
      endpoint: "https://auth.example.test/oauth2/introspect",
      issuer: "https://auth.example.test/issuer",
      resource: "https://lmx.example.test/mcp",
      client_id: "lmx-resource-server",
      client_secret: "resource-server-secret",
      requester:,
      clock: -> { now }
    )
  end

  it "returns trusted normalized claims for an active resource-bound token" do
    claims = client.verify("oauth-access-token")

    expect(claims).to be_a(described_class::Claims)
    expect(claims.issuer).to eq("https://auth.example.test/issuer")
    expect(claims.subject).to eq("external-user-123")
    expect(claims.client_id).to eq("chatgpt-client")
    expect(claims.scopes).to eq(%w[read:openings submit:openings])
    expect(claims.audiences).to eq([ "https://lmx.example.test/mcp" ])
    expect(claims.expires_at).to eq(Time.at(now.to_i + 300))
  end

  it "treats an inactive token as unauthenticated" do
    payload[:active] = false

    expect(client.verify("inactive-token")).to be_nil
  end

  it "rejects a token whose issuer claim contradicts the configured authorization server" do
    payload[:iss] = "https://other.example.test"

    expect(client.verify("wrong-issuer")).to be_nil
  end

  it "accepts introspection responses that omit iss because the endpoint is issuer-bound" do
    payload.delete(:iss)

    expect(client.verify("issuer-bound-by-endpoint").issuer).to eq("https://auth.example.test/issuer")
  end

  it "rejects a token that is not audience-bound to the exact MCP resource" do
    payload[:aud] = [ "https://api.example.test" ]

    expect(client.verify("wrong-audience")).to be_nil
  end

  it "rejects an expired token even if introspection incorrectly reports it active" do
    payload[:exp] = now.to_i - 1

    expect(client.verify("expired-token")).to be_nil
  end

  it "rejects malformed expiry claims" do
    payload[:exp] = "later"

    expect(client.verify("bad-expiry")).to be_nil
  end

  it "raises unavailable when the authorization server cannot verify the token" do
    requester = ->(_token) { [ 503, "temporarily unavailable" ] }
    client = described_class.new(
      endpoint: "https://auth.example.test/oauth2/introspect",
      issuer: "https://auth.example.test/issuer",
      resource: "https://lmx.example.test/mcp",
      client_id: "lmx-resource-server",
      client_secret: "resource-server-secret",
      requester:
    )

    expect { client.verify("token") }
      .to raise_error(described_class::Unavailable, /HTTP 503/)
  end

  it "refuses non-HTTPS introspection endpoints" do
    expect do
      described_class.new(
        endpoint: "http://auth.example.test/introspect",
        issuer: "https://auth.example.test/issuer",
        resource: "https://lmx.example.test/mcp",
        client_id: "lmx-resource-server",
        client_secret: "resource-server-secret"
      )
    end.to raise_error(described_class::ConfigurationError, /HTTPS/)
  end
end
