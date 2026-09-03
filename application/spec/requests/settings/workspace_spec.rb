# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Workspace settings", type: :request do
  it "lets a workspace admin update workspace branding" do
    user = User.create!(name: "Admin", email: "admin@example.com", password: "Password12345!", verified: true)
    organization = Organization.create!(name: "Original workspace", slug: "original-workspace")
    Membership.create!(user:, organization:, role: "workspace_admin")
    sign_in user

    get settings_workspace_path

    expect(response).to have_http_status(:success)
    expect(inertia_component).to eq("settings/workspaces/show")

    patch settings_workspace_path, params: { name: "Renamed workspace" }

    expect(response).to redirect_to(settings_workspace_path)
    expect(organization.reload.name).to eq("Renamed workspace")
  end

  it "does not expose branding settings to non-admin members" do
    user = User.create!(name: "Recruiter", email: "recruiter@example.com", password: "Password12345!", verified: true)
    organization = Organization.create!(name: "Restricted workspace", slug: "restricted-workspace")
    Membership.create!(user:, organization:, role: "recruiter")
    sign_in user

    get settings_workspace_path

    expect(response).to have_http_status(:not_found)
  end
end
