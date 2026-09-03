# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Workspace home", type: :request do
  it "renders the default home dashboard for the selected workspace" do
    user = User.create!(name: "Ada Lovelace", email: "ada@example.com", password: "Password12345!", verified: true)
    organization = Organization.create!(name: "Home workspace", slug: "home-workspace")
    Membership.create!(user:, organization:, role: "recruiter")
    sign_in user

    get root_path

    expect(response).to have_http_status(:success)
    expect(inertia_component).to eq("dashboard/index")
    expect(response.body).to include('"greeting_name":"Ada"')
  end

  it "does not retain the legacy dashboard URL" do
    get "/dashboard"

    expect(response).to have_http_status(:not_found)
  end
end
