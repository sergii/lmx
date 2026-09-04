# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::Mcp::WorkspaceGrantPolicy do
  subject(:policy) { described_class.new }

  def membership(role:, active: true, client_portal: false)
    {
      id: "membership_opaque",
      workspace_id: "org_opaque",
      user_id: "user_opaque",
      role:,
      active:,
      client_portal:
    }
  end

  it "keeps the explicit policy allowlist synchronized with published Integration capabilities" do
    published = (
      Integration::Read::Contracts.all.map(&:required_capability) +
      Integration::Command::Contracts.all.map(&:required_capability)
    ).uniq.sort

    expect(described_class::WORKSPACE_WIDE_CAPABILITIES.sort).to eq(published)
  end

  it "allows the current workspace-wide MCP capabilities for active internal roles" do
    %w[workspace_admin recruiting_ops_lead recruiter].each do |role|
      expect(policy.capabilities_for(membership(role:))).to eq(
        described_class::WORKSPACE_WIDE_CAPABILITIES
      )
    end
  end

  it "fails closed for inactive or client-scoped memberships" do
    expect(policy.capabilities_for(membership(role: "recruiter", active: false))).to be_empty
    expect(
      policy.capabilities_for(
        membership(role: "client_hiring_manager", client_portal: true)
      )
    ).to be_empty
    expect(
      policy.capabilities_for(
        membership(role: "client_interviewer", client_portal: true)
      )
    ).to be_empty
  end

  it "only lets active workspace admins manage persisted OAuth grants" do
    expect(policy.can_manage_grants?(membership(role: "workspace_admin"))).to be(true)
    expect(policy.can_manage_grants?(membership(role: "recruiting_ops_lead"))).to be(false)
    expect(policy.can_manage_grants?(membership(role: "workspace_admin", active: false))).to be(false)
  end

  it "requires requested grants to remain inside the role maximum" do
    recruiter = membership(role: "recruiter")
    client = membership(role: "client_hiring_manager", client_portal: true)

    expect(policy.allowed?(recruiter, %w[read:openings submit:openings])).to be(true)
    expect(policy.allowed?(client, %w[read:openings])).to be(false)
    expect(policy.allowed?(recruiter, %w[admin:everything])).to be(false)
  end
end
