# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Workspace onboarding", type: :request do
  it "takes a new user through profile, workspace, setup, and completion" do
    user = User.create!(name: "Ada", email: "ada@example.com", password: "Password12345!", verified: true)
    sign_in user

    get onboarding_profile_path
    expect(response).to have_http_status(:success)
    expect(inertia_component).to eq("onboarding/profile")

    patch onboarding_profile_path, params: { name: "Ada Lovelace" }
    expect(response).to redirect_to(onboarding_workspace_path)
    expect(user.reload.name).to eq("Ada Lovelace")

    post onboarding_workspace_path, params: { name: "Analytical Engine" }
    expect(response).to redirect_to(onboarding_use_cases_path)

    organization = user.reload.organizations.sole
    membership = user.memberships.sole
    expect(membership.role).to eq("workspace_admin")

    get onboarding_use_cases_path
    expect(response).to have_http_status(:success)
    expect(inertia_component).to eq("onboarding/use-cases")

    patch onboarding_use_cases_path, params: { use_cases: %w[sourcing client_collaboration unknown] }
    expect(response).to redirect_to(onboarding_team_path)
    expect(organization.reload.onboarding_use_cases).to contain_exactly("sourcing", "client_collaboration")

    post complete_onboarding_path
    expect(response).to redirect_to(home_path)
    expect(user.reload).to be_onboarding_completed
  end

  it "sends a signed-in user without a workspace to onboarding" do
    user = User.create!(name: "No workspace", email: "empty@example.com", password: "Password12345!", verified: true)

    post sign_in_path, params: { email: user.email, password: "Password12345!" }

    expect(response).to redirect_to(onboarding_profile_path)
  end

  it "does not restart onboarding for a user who already has a workspace" do
    user = User.create!(name: "Existing", email: "existing@example.com", password: "Password12345!", verified: true)
    organization = Organization.create!(name: "Existing Workspace", slug: "existing-workspace")
    Membership.create!(user:, organization:, role: "workspace_admin")
    sign_in user

    get onboarding_profile_path

    expect(response).to redirect_to(home_path)
  end
end
