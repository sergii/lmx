# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::McpOauthPairing do
  let(:resource) { "https://www.example.com/mcp" }
  let(:claims) do
    Integration::Mcp::OauthIntrospectionClient::Claims.new(
      issuer: "https://auth.example.test/issuer",
      subject: "external-user-123",
      client_id: "https://client.example.test/mcp.json",
      scopes: %w[read:openings submit:openings unrelated:scope],
      audiences: [ resource ],
      expires_at: Time.current + 10.minutes
    )
  end

  it "round-trips verified OAuth identity without carrying the bearer token" do
    issued = described_class.issue(claims:, resource:)
    ticket = described_class.describe(token: issued.token, resource:)

    expect(ticket).to have_attributes(
      issuer: claims.issuer,
      subject: claims.subject,
      client_id: claims.client_id,
      scopes: %w[read:openings submit:openings unrelated:scope],
      resource:
    )
    expect(ticket.expires_at).to be <= claims.expires_at
    expect(issued.token).not_to include(claims.subject)
    expect(described_class.pairable_capabilities(ticket.scopes)).to eq(
      %w[read:openings submit:openings]
    )
  end

  it "binds a ticket to the configured MCP resource" do
    issued = described_class.issue(claims:, resource:)

    expect do
      described_class.describe(
        token: issued.token,
        resource: "https://other.example.com/mcp"
      )
    end.to raise_error(
      described_class::InvalidTicket,
      "pairing ticket is for a different MCP resource"
    )
  end

  it "rejects tampered tickets" do
    issued = described_class.issue(claims:, resource:)

    expect do
      described_class.describe(token: "#{issued.token}tampered", resource:)
    end.to raise_error(described_class::InvalidTicket)
  end

  it "creates an audited membership-bound grant from a verified ticket" do
    workspace = Organization.create!(name: "Pairing", slug: "pairing")
    admin_user = User.create!(
      name: "Pairing Admin",
      email: "pairing-admin@example.com",
      password: "Password12345!",
      verified: true
    )
    recruiter_user = User.create!(
      name: "Pairing Recruiter",
      email: "pairing-recruiter@example.com",
      password: "Password12345!",
      verified: true
    )
    admin = Membership.create!(user: admin_user, organization: workspace, role: "workspace_admin")
    recruiter = Membership.create!(user: recruiter_user, organization: workspace, role: "recruiter")
    issued = described_class.issue(claims:, resource:)

    grant = described_class.approve(
      token: issued.token,
      resource:,
      workspace_id: workspace.typed_id,
      membership_id: recruiter.typed_id,
      capabilities: %w[read:openings],
      managed_by_membership_id: admin.typed_id
    )

    expect(grant).to include(
      "workspace_id" => workspace.typed_id,
      "issuer" => claims.issuer,
      "subject" => claims.subject,
      "client_id" => claims.client_id,
      "principal" => recruiter_user.typed_id,
      "capabilities" => %w[read:openings],
      "created_by" => admin.typed_id
    )
    expect(grant.fetch("credential")).to start_with("mcp-oauth:")
    expect(grant.fetch("executor")).to start_with("oauth:")

    history = Integration::McpOauthGrantRegistry.grant_history(
      workspace_id: workspace.typed_id,
      grant_id: grant.fetch("id")
    )
    expect(history.map { _1.fetch("action") }).to eq([ "created" ])
    expect(history.first.fetch("managed_by")).to eq(admin.typed_id)
  end

  it "cannot approve a capability the verified token did not request" do
    workspace = Organization.create!(name: "Pairing scope", slug: "pairing-scope")
    admin_user = User.create!(
      name: "Scope Admin",
      email: "pairing-scope-admin@example.com",
      password: "Password12345!",
      verified: true
    )
    admin = Membership.create!(user: admin_user, organization: workspace, role: "workspace_admin")
    issued = described_class.issue(claims:, resource:)

    expect do
      described_class.approve(
        token: issued.token,
        resource:,
        workspace_id: workspace.typed_id,
        membership_id: admin.typed_id,
        capabilities: %w[read:candidates],
        managed_by_membership_id: admin.typed_id
      )
    end.to raise_error(
      described_class::InvalidInput,
      "selected capabilities were not requested by the verified OAuth token"
    )
  end
end
