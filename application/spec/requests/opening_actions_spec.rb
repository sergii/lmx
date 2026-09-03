# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Opening Personal CRM actions", type: :request do
  let!(:user) do
    User.create!(
      name: "Ada Lovelace",
      email: "ada-opening-actions@example.com",
      password: "Password12345!",
      verified: true
    )
  end
  let!(:organization) { Organization.create!(name: "Opening actions", slug: "opening-actions") }
  let!(:membership) { Membership.create!(user:, organization:, role: "workspace_admin") }
  let!(:candidate_id) do
    WorkspaceContext.with(organization, membership:) do
      TalentProfile::Api.create_candidate(
        first_name: "Ada",
        last_name: "Lovelace",
        linked_user_id: user.typed_id
      ).dig(:candidate, :id)
    end
  end
  let!(:opening_id) do
    MarketCatalog::Api.create_opening(
      canonical_title: "Senior Ruby Engineer",
      first_seen_at: Time.current
    ).fetch(:id)
  end

  before do
    sign_in user
  end

  it "saves the opening without creating an application attempt" do
    post save_opening_path(opening_id)

    expect(response).to redirect_to(opening_path(opening_id))
    expect(response).to have_http_status(:see_other)

    personal = personal_state
    expect(personal.dig(:disposition, :state)).to eq("saved")
    expect(personal.fetch(:application)).to be_nil
  end

  it "ignores the opening as personal state" do
    post ignore_opening_path(opening_id)

    expect(response).to redirect_to(opening_path(opening_id))
    expect(personal_state.dig(:disposition, :state)).to eq("ignored")
  end

  it "marks the opening applied and renders the attempt on the detail screen" do
    post apply_opening_path(opening_id)

    expect(response).to redirect_to(opening_path(opening_id))
    personal = personal_state
    expect(personal.dig(:disposition, :state)).to eq("applied")
    expect(personal.dig(:application, :attempt_number)).to eq(1)

    get opening_path(opening_id)

    expect(response).to have_http_status(:success)
    expect(response.body).to include('"state":"applied"')
    expect(response.body).to include('"attempt_number":1')
  end

  it "does not create a duplicate attempt when mark applied is retried" do
    post apply_opening_path(opening_id)
    first_application_id = personal_state.dig(:application, :id)

    post apply_opening_path(opening_id)

    expect(personal_state.dig(:application, :id)).to eq(first_application_id)
    WorkspaceContext.with(organization, membership:) do
      expect(PersonalCrm::Application.count).to eq(1)
    end
  end

  it "requires a canonical Candidate linked to the signed-in user" do
    WorkspaceContext.with(organization, membership:) do
      candidate_uuid = PersonalCrm::Identifiers.uuid(candidate_id, prefix: "candidate")
      TalentProfile::Candidate.find(candidate_uuid).update!(linked_user_id: nil)
    end

    post save_opening_path(opening_id)

    expect(response).to redirect_to(opening_path(opening_id))
    expect(flash[:alert]).to match(/Complete your candidate profile/)
  end

  private

  def personal_state
    WorkspaceContext.with(organization, membership:) do
      PersonalCrm::Api.fetch_opportunity(
        workspace_id: organization.typed_id,
        candidate_id:,
        job_opening_id: opening_id
      )
    end
  end
end
