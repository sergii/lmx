# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workspace::Api do
  let!(:workspace) { Organization.create!(name: "Public API Workspace", slug: "public-api-workspace") }
  let!(:other_workspace) { Organization.create!(name: "Other Workspace", slug: "other-workspace") }

  after do
    Current.reset
    ActiveRecord::Base.connection.execute("RESET app.current_organization")
  end

  it "executes the block inside the resolved workspace and restores the previous scope" do
    result = described_class.with_workspace(workspace_id: workspace.typed_id) do
      expect(Current.organization).to eq(workspace)
      expect(Current.membership).to be_nil
      expect(database_workspace_id).to eq(workspace.id.to_s)

      :result
    end

    expect(result).to eq(:result)
    expect(Current.organization).to be_nil
    expect(Current.membership).to be_nil
    expect(database_workspace_id).to be_blank
  end

  it "resolves an optional membership and requires it to belong to the workspace" do
    user = User.create!(
      name: "Workspace API User",
      email: "workspace-api@example.com",
      password: "Password12345!",
      verified: true
    )
    membership = Membership.create!(user:, organization: workspace, role: "workspace_admin")

    described_class.with_workspace(workspace_id: workspace.typed_id, membership_id: membership.typed_id) do
      expect(Current.organization).to eq(workspace)
      expect(Current.membership).to eq(membership)
      expect(database_workspace_id).to eq(workspace.id.to_s)
    end

    expect do
      described_class.with_workspace(workspace_id: other_workspace.typed_id, membership_id: membership.typed_id) do
        raise "must not execute"
      end
    end.to raise_error(described_class::NotFound, "membership not found in workspace")
  end

  it "publishes immutable membership authorization facts by membership or user" do
    user = User.create!(
      name: "Authorization Snapshot User",
      email: "authorization-snapshot@example.com",
      password: "Password12345!",
      verified: true
    )
    membership = Membership.create!(
      user:,
      organization: workspace,
      role: "recruiter",
      active: true
    )

    expected = {
      id: membership.typed_id,
      workspace_id: workspace.typed_id,
      user_id: user.typed_id,
      role: "recruiter",
      active: true,
      client_portal: false
    }

    by_membership = described_class.fetch_membership(
      workspace_id: workspace.typed_id,
      membership_id: membership.typed_id
    )
    by_user = described_class.fetch_membership_for_user(
      workspace_id: workspace.typed_id,
      user_id: user.typed_id
    )

    expect(by_membership).to eq(expected)
    expect(by_user).to eq(expected)
    expect(by_membership).to be_frozen
  end

  it "does not resolve a membership or user through another workspace" do
    user = User.create!(
      name: "Scoped Authorization User",
      email: "scoped-authorization@example.com",
      password: "Password12345!",
      verified: true
    )
    membership = Membership.create!(user:, organization: workspace, role: "recruiter")

    expect do
      described_class.fetch_membership(
        workspace_id: other_workspace.typed_id,
        membership_id: membership.typed_id
      )
    end.to raise_error(described_class::NotFound, "membership not found in workspace")

    expect do
      described_class.fetch_membership_for_user(
        workspace_id: other_workspace.typed_id,
        user_id: user.typed_id
      )
    end.to raise_error(described_class::NotFound, "membership not found in workspace")
  end

  it "does not expose Active Record lookup errors at the public boundary" do
    expect do
      described_class.with_workspace(workspace_id: "candidate_01invalid") { :unreachable }
    end.to raise_error(described_class::NotFound, "workspace not found")
  end

  it "restores workspace state when the caller block raises" do
    expect do
      described_class.with_workspace(workspace_id: workspace.typed_id) { raise "boom" }
    end.to raise_error("boom")

    expect(Current.organization).to be_nil
    expect(Current.membership).to be_nil
    expect(database_workspace_id).to be_blank
  end

  it "rejects incomplete boundary input before touching workspace state" do
    expect do
      described_class.with_workspace(workspace_id: "") { :unreachable }
    end.to raise_error(described_class::InvalidInput, "workspace_id is required")

    expect do
      described_class.with_workspace(workspace_id: workspace.typed_id, membership_id: "") { :unreachable }
    end.to raise_error(described_class::InvalidInput, "membership_id must be omitted or present")

    expect do
      described_class.fetch_membership(
        workspace_id: workspace.typed_id,
        membership_id: ""
      )
    end.to raise_error(described_class::InvalidInput, "membership_id is required")

    expect do
      described_class.fetch_membership_for_user(
        workspace_id: workspace.typed_id,
        user_id: ""
      )
    end.to raise_error(described_class::InvalidInput, "user_id is required")
  end

  def database_workspace_id
    ActiveRecord::Base.connection.select_value("SELECT current_setting('app.current_organization', true)")
  end
end
