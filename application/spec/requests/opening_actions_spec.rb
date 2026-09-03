# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Opening actions", type: :request do
  let!(:user) do
    User.create!(
      name: "Ada Lovelace",
      email: "ada-opening-actions@example.com",
      password: "Password12345!",
      verified: true
    )
  end
  let!(:organization) { Organization.create!(name: "Opening actions workspace", slug: "opening-actions-workspace") }
  let!(:membership) { Membership.create!(user:, organization:, role: "workspace_admin") }
  let!(:opening) do
    MarketCatalog::Api.create_opening(
      canonical_title: "Senior Ruby Engineer",
      first_seen_at: Time.current
    )
  end
  let!(:candidate) do
    WorkspaceContext.with(organization, membership:) do
      TalentProfile::Api.create_candidate(
        first_name: "Ada",
        last_name: "Lovelace",
        linked_user_id: user.typed_id,
        profile: { skills: [ "Ruby", "Rails" ] }
      ).fetch(:candidate)
    end
  end

  before do
    sign_in user
  end

  it "lets the workspace user save and ignore the canonical opening" do
    post_action("save", "web-save-1")
    expect(response).to have_http_status(:see_other)
    expect(personal_context.dig(:disposition, :state)).to eq("saved")

    post_action("ignore", "web-ignore-1")
    expect(response).to have_http_status(:see_other)
    expect(personal_context.dig(:disposition, :state)).to eq("ignored")
  end

  it "creates repeat application attempts and does not duplicate a retried web command" do
    post_action("apply", "web-apply-1")
    expect(response).to have_http_status(:see_other)

    post_action("apply", "web-apply-1")
    expect(response).to have_http_status(:see_other)

    post_action("apply", "web-apply-2")
    expect(response).to have_http_status(:see_other)

    context = personal_context
    expect(context.dig(:disposition, :state)).to eq("saved")
    expect(context.fetch(:applications).size).to eq(2)
    expect(context.fetch(:applications).first.fetch(:next_action)).to eq("Submit application")
  end

  it "renders the Personal CRM state back into Opening Detail" do
    post_action("apply", "web-detail-1")

    get opening_path(opening.fetch(:id))

    expect(response).to have_http_status(:success)
    expect(inertia_component).to eq("openings/show")
    expect(response.body).to include('"personal_crm"')
    expect(response.body).to include('"state":"saved"')
    expect(response.body).to include('"stage":"applying"')
    expect(response.body).to include("Submit application")
  end

  it "rejects an unknown opening action without changing personal state" do
    post_action("unknown", "web-unknown-1")

    expect(response).to have_http_status(:unprocessable_entity)
    expect(personal_context.fetch(:applications)).to be_empty
    expect(personal_context[:disposition]).to be_nil
  end

  private

  def post_action(kind, idempotency_key)
    post "/openings/#{opening.fetch(:id)}/actions", params: { kind:, idempotency_key: }
  end

  def personal_context
    WorkspaceContext.with(organization, membership:) do
      PersonalCrm::Api.fetch_opening_context(
        workspace_id: organization.typed_id,
        candidate_id: candidate.fetch(:id),
        job_opening_id: opening.fetch(:id)
      )
    end
  end
end
