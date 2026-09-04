# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::Mcp::PersistedOauthGrantStore do
  let!(:workspace) { Organization.create!(name: "Persisted OAuth", slug: "persisted-oauth") }
  let(:claims) do
    Integration::Mcp::OauthIntrospectionClient::Claims.new(
      issuer: "https://auth.example.test/issuer",
      subject: "external-user-123",
      client_id: "chatgpt-client",
      scopes: %w[read:openings submit:openings],
      audiences: [ "https://lmx.example.test/mcp" ],
      expires_at: Time.now + 300
    )
  end

  let!(:grant) do
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
      capabilities: %w[read:openings read:matches],
      managed_by: "user:admin"
    )
  end

  it "intersects verified scopes with persisted server-side capabilities" do
    identity = described_class.new.resolve(claims)

    expect(identity.workspace_id).to eq(workspace.typed_id)
    expect(identity.principal).to eq("user:serhii")
    expect(identity.credential).to eq("mcp-oauth:chatgpt")
    expect(identity.capabilities).to eq([ "read:openings" ])
    expect(identity.runtime_id).to start_with("mcp-oauth:")
  end

  it "fails closed immediately after persisted revocation" do
    Integration::McpOauthGrantRegistry.revoke_grant(
      workspace_id: workspace.typed_id,
      grant_id: grant.fetch("id"),
      managed_by: "user:security",
      reason: "compromised"
    )

    expect(described_class.new.resolve(claims)).to be_nil
  end

  it "does not resolve a different external subject" do
    different_claims = Integration::Mcp::OauthIntrospectionClient::Claims.new(
      issuer: claims.issuer,
      subject: "other-user",
      client_id: claims.client_id,
      scopes: claims.scopes,
      audiences: claims.audiences,
      expires_at: claims.expires_at
    )

    expect(described_class.new.resolve(different_claims)).to be_nil
  end
end
