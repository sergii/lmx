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
  end

  def database_workspace_id
    ActiveRecord::Base.connection.select_value("SELECT current_setting('app.current_organization', true)")
  end
end
