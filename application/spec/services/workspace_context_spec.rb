# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkspaceContext do
  describe ".with" do
    let!(:first_workspace) { Organization.create!(name: "First Workspace", slug: "first-workspace") }
    let!(:second_workspace) { Organization.create!(name: "Second Workspace", slug: "second-workspace") }

    after do
      Current.reset
      ActiveRecord::Base.connection.execute("RESET app.current_organization")
    end

    it "sets the application and database workspace for the duration of the block" do
      described_class.with(first_workspace) do
        expect(Current.organization).to eq(first_workspace)
        expect(Current.membership).to be_nil
        expect(database_workspace_id).to eq(first_workspace.id.to_s)
      end

      expect(Current.organization).to be_nil
      expect(database_workspace_id).to be_blank
    end

    it "replaces and restores membership together with nested workspace context" do
      user = User.create!(name: "Workspace User", email: "workspace@example.com", password: "Password12345!", verified: true)
      membership = Membership.create!(user:, organization: first_workspace, role: "workspace_admin")

      described_class.with(first_workspace, membership:) do
        expect(Current.membership).to eq(membership)

        described_class.with(second_workspace) do
          expect(Current.organization).to eq(second_workspace)
          expect(Current.membership).to be_nil
          expect(database_workspace_id).to eq(second_workspace.id.to_s)
        end

        expect(Current.organization).to eq(first_workspace)
        expect(Current.membership).to eq(membership)
        expect(database_workspace_id).to eq(first_workspace.id.to_s)
      end
    end

    it "restores the context when the block raises" do
      expect do
        described_class.with(first_workspace) { raise "boom" }
      end.to raise_error("boom")

      expect(Current.organization).to be_nil
      expect(Current.membership).to be_nil
      expect(database_workspace_id).to be_blank
    end
  end

  def database_workspace_id
    ActiveRecord::Base.connection.select_value("SELECT current_setting('app.current_organization', true)")
  end
end
