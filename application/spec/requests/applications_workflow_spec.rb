# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Applications workflow", type: :request do
  let!(:user) do
    User.create!(
      name: "Ada Lovelace",
      email: "ada-applications-workflow@example.com",
      password: "Password12345!",
      verified: true
    )
  end
  let!(:organization) { Organization.create!(name: "Applications workspace", slug: "applications-workspace") }
  let!(:membership) { Membership.create!(user:, organization:, role: "workspace_admin") }
  let!(:company) do
    MarketCatalog::Api.create_company(canonical_name: "Acme Labs")
  end
  let!(:opening) do
    MarketCatalog::Api.create_opening(
      canonical_title: "Senior Ruby Engineer",
      primary_company_id: company.fetch(:id),
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

  it "renders the canonical applications list with opening context" do
    application = start_application("request-list-1")

    get applications_path(view: "list")

    expect(response).to have_http_status(:success)
    expect(inertia_component).to eq("applications/index")
    expect(response.body).to include(application.fetch(:id))
    expect(response.body).to include("Senior Ruby Engineer")
    expect(response.body).to include("Acme Labs")
    expect(response.body).to include('"initial_view":"list"')
  end

  it "changes application stage through the Personal CRM command boundary" do
    application = start_application("request-stage-start")

    patch application_path(application.fetch(:id)), params: {
      kind: "stage",
      stage: "applied",
      idempotency_key: "request-stage-1",
      return_view: "kanban"
    }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(applications_path(view: "kanban"))

    projected = fetch_application(application.fetch(:id))
    expect(projected.fetch(:stage)).to eq("applied")
    expect(projected.fetch(:applied_at)).to be_present
    expect(
      Platform::DomainEvent.where(event_type: PersonalCrm::Api::APPLICATION_STAGE_CHANGED).count
    ).to eq(1)
  end

  it "updates the next action through the Personal CRM command boundary" do
    application = start_application("request-action-start")
    due_at = 1.day.from_now.change(usec: 0)

    patch application_path(application.fetch(:id)), params: {
      kind: "next_action",
      next_action: "Follow up with recruiter",
      next_action_at: due_at.iso8601,
      idempotency_key: "request-action-1",
      return_view: "table"
    }

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(applications_path(view: "table"))

    projected = fetch_application(application.fetch(:id))
    expect(projected.fetch(:next_action)).to eq("Follow up with recruiter")
    expect(projected.fetch(:next_action_at)).to be_within(1.second).of(due_at)
  end

  it "does not let the current user mutate another candidate's application" do
    other_candidate = WorkspaceContext.with(organization, membership:) do
      TalentProfile::Api.create_candidate(
        first_name: "Grace",
        last_name: "Hopper",
        profile: { skills: [ "Compilers" ] }
      ).fetch(:candidate)
    end
    application = WorkspaceContext.with(organization, membership:) do
      PersonalCrm::Api.start_application(
        workspace_id: organization.typed_id,
        candidate_id: other_candidate.fetch(:id),
        job_opening_id: opening.fetch(:id),
        command: command("other-candidate-start")
      ).fetch(:application)
    end

    patch application_path(application.fetch(:id)), params: {
      kind: "stage",
      stage: "screening",
      idempotency_key: "other-candidate-stage"
    }

    expect(response).to have_http_status(:not_found)
    expect(fetch_application(application.fetch(:id)).fetch(:stage)).to eq("applying")
  end

  private

  def start_application(key)
    WorkspaceContext.with(organization, membership:) do
      PersonalCrm::Api.start_application(
        workspace_id: organization.typed_id,
        candidate_id: candidate.fetch(:id),
        job_opening_id: opening.fetch(:id),
        command: command(key)
      ).fetch(:application)
    end
  end

  def fetch_application(application_id)
    WorkspaceContext.with(organization, membership:) do
      PersonalCrm::Api.fetch_application(
        workspace_id: organization.typed_id,
        application_id:
      )
    end
  end

  def command(key)
    {
      idempotency_key: key,
      principal: user.typed_id,
      credential: "request-spec",
      actor: user.typed_id,
      executor: "rspec",
      interface: "test",
      client: "rspec"
    }
  end
end
