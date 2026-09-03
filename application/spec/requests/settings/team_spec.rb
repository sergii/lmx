# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Team invitations", type: :request do
  it "lets a workspace admin create and view a pending invitation" do
    user = User.create!(name: "Admin", email: "admin@example.com", password: "Password12345!", verified: true)
    organization = Organization.create!(name: "Team workspace", slug: "team-workspace")
    Membership.create!(user:, organization:, role: "workspace_admin")
    sign_in user

    get settings_team_path

    expect(response).to have_http_status(:success)
    expect(inertia_component).to eq("settings/teams/show")

    post settings_team_path, params: { email: "new.recruiter@example.com", role: "recruiter" }

    expect(response).to redirect_to(settings_team_path)
    invitation = organization.workspace_invitations.sole
    expect(invitation).to have_attributes(email: "new.recruiter@example.com", role: "recruiter", status: "pending", invited_by: user)
  end

  it "does not allow a recruiter to access team invitations" do
    user = User.create!(name: "Recruiter", email: "recruiter@example.com", password: "Password12345!", verified: true)
    organization = Organization.create!(name: "Private workspace", slug: "private-workspace")
    Membership.create!(user:, organization:, role: "recruiter")
    sign_in user

    get settings_team_path

    expect(response).to have_http_status(:not_found)
  end
end
