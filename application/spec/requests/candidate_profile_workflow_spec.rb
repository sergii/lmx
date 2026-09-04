# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Candidate profile workflow", type: :request do
  let!(:user) do
    User.create!(
      name: "Ada Lovelace",
      email: "ada-profile-workflow@example.com",
      password: "Password12345!",
      verified: true
    )
  end
  let!(:organization) { Organization.create!(name: "Profile workspace", slug: "profile-workspace") }
  let!(:membership) { Membership.create!(user:, organization:, role: "workspace_admin") }
  let!(:candidate) do
    WorkspaceContext.with(organization, membership:) do
      TalentProfile::Api.create_candidate(
        first_name: "Ada",
        last_name: "Lovelace",
        email: "ada@example.com",
        linked_user_id: user.typed_id,
        profile: {
          skills: [ "Ruby", "Rails" ],
          target: "Senior Rails Engineer"
        }
      ).fetch(:candidate)
    end
  end

  before do
    sign_in user
  end

  it "renders the current user's canonical profile and version history" do
    get profile_path

    expect(response).to have_http_status(:success)
    expect(inertia_component).to eq("profile/show")
    expect(response.body).to include(candidate.fetch(:id))
    expect(response.body).to include("Senior Rails Engineer")
    expect(response.body).to include('"version_number":1')
  end

  it "creates a new immutable canonical profile version instead of mutating the prior snapshot" do
    first = profile_versions.first

    patch profile_path, params: {
      profile: {
        skills: [ "Ruby", "Rails", "PostgreSQL" ],
        target: "Staff Rails Engineer"
      }
    }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(profile_path)

    versions = profile_versions
    expect(versions.map { _1.fetch(:version_number) }).to eq([ 2, 1 ])
    expect(versions.first.fetch(:profile)).to eq(
      "skills" => [ "Ruby", "Rails", "PostgreSQL" ],
      "target" => "Staff Rails Engineer"
    )
    expect(versions.last.fetch(:id)).to eq(first.fetch(:id))
    expect(versions.last.fetch(:profile)).to eq(first.fetch(:profile))
  end

  it "always writes through the Candidate linked to the current user" do
    other_candidate = WorkspaceContext.with(organization, membership:) do
      TalentProfile::Api.create_candidate(
        first_name: "Grace",
        last_name: "Hopper",
        profile: { skills: [ "Compilers" ] }
      ).fetch(:candidate)
    end

    patch profile_path, params: {
      candidate_id: other_candidate.fetch(:id),
      profile: { skills: [ "Ruby", "Rails", "Security" ] }
    }

    expect(response).to have_http_status(:see_other)

    linked_profile = WorkspaceContext.with(organization, membership:) do
      TalentProfile::Api.fetch_latest_profile(candidate_id: candidate.fetch(:id))
    end
    other_profile = WorkspaceContext.with(organization, membership:) do
      TalentProfile::Api.fetch_latest_profile(candidate_id: other_candidate.fetch(:id))
    end

    expect(linked_profile.fetch(:profile)).to eq("skills" => [ "Ruby", "Rails", "Security" ])
    expect(other_profile.fetch(:profile)).to eq("skills" => [ "Compilers" ])
  end

  private

  def profile_versions
    WorkspaceContext.with(organization, membership:) do
      TalentProfile::Api.fetch_profile_versions(candidate_id: candidate.fetch(:id))
    end
  end
end
