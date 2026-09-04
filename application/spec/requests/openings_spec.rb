# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Openings inbox", type: :request do
  let!(:user) do
    User.create!(
      name: "Ada Lovelace",
      email: "ada-openings@example.com",
      password: "Password12345!",
      verified: true
    )
  end
  let!(:organization) { Organization.create!(name: "Openings workspace", slug: "openings-workspace") }
  let!(:membership) { Membership.create!(user:, organization:, role: "workspace_admin") }

  before do
    sign_in user
  end

  it "renders canonical openings with source evidence and the current user's latest assessment" do
    now = Time.current.change(usec: 0)
    company = MarketCatalog::Api.create_company(canonical_name: "Example Labs", primary_domain: "example.test")
    opening = MarketCatalog::Api.create_opening(
      canonical_title: "Senior Ruby Engineer",
      primary_company_id: company.fetch(:id),
      first_seen_at: now,
      metadata: {
        location: "Kyiv / Remote",
        compensation_text: "$6,000–$7,000",
        remote_policy: "Remote within Europe"
      }
    )
    posting = MarketCatalog::Api.record_posting(
      source_key: "dou",
      title: "Senior Ruby Engineer",
      observed_at: now,
      external_id: "opening-spec-1",
      canonical_url: "https://jobs.example.test/ruby",
      publisher_company_id: company.fetch(:id)
    )
    MarketCatalog::Api.resolve_posting_opening_link(
      posting_id: posting.fetch(:id),
      opening_id: opening.fetch(:id),
      confidence: 1.0,
      evidence: [ "explicit test link" ],
      resolver_key: "request_spec",
      resolver_version: "1"
    )

    candidate = WorkspaceContext.with(organization, membership:) do
      TalentProfile::Api.create_candidate(
        first_name: "Ada",
        last_name: "Lovelace",
        linked_user_id: user.typed_id,
        profile: { skills: [ "Ruby", "Rails" ] }
      )
    end

    WorkspaceContext.with(organization, membership:) do
      Intelligence::Api.record_match_assessment(
        workspace_id: organization.typed_id,
        candidate_id: candidate.dig(:candidate, :id),
        candidate_profile_version_id: candidate.dig(:profile_version, :id),
        job_opening_id: opening.fetch(:id),
        opening_evidence_cutoff: now,
        scoring_policy_version: "request-spec-v1",
        opportunity_score: 92,
        action_priority: 87,
        recommendation: "Strong Rails and infrastructure overlap"
      )
    end

    get openings_path

    expect(response).to have_http_status(:success)
    expect(inertia_component).to eq("openings/index")
    expect(response.body).to include("Senior Ruby Engineer")
    expect(response.body).to include("Example Labs")
    expect(response.body).to include('\"key\":\"dou\"')
    expect(response.body).to include('\"opportunity_score\":92.0')
    expect(response.body).to include('\"action_priority\":87.0')
    expect(response.body).to include("Strong Rails and infrastructure overlap")
  end

  it "still renders the market inbox before a personal canonical Candidate exists" do
    MarketCatalog::Api.create_opening(
      canonical_title: "Platform Engineer",
      first_seen_at: Time.current
    )

    get openings_path

    expect(response).to have_http_status(:success)
    expect(inertia_component).to eq("openings/index")
    expect(response.body).to include("Platform Engineer")
    expect(response.body).to include('\"candidate\":null')
  end

  it "renders the manual opening ingress" do
    get new_opening_path

    expect(response).to have_http_status(:success)
    expect(inertia_component).to eq("openings/new")
  end

  it "creates a canonical opening without requiring a public URL" do
    expect do
      post openings_path, params: {
        title: "Principal Rails Engineer",
        company_name: "Private Search Co",
        location: "Europe",
        remote_policy: "Remote",
        compensation: "€90k-€110k",
        notes: "Introduced by a recruiter",
        idempotency_key: "manual-no-url-1"
      }
    end.to change(Platform::DomainEvent.where(event_type: "job_opening.created"), :count).by(1)
      .and change(Platform::OutboxMessage.where(message_type: "job_opening.created"), :count).by(1)

    opening = redirected_opening
    event = Platform::DomainEvent.where(event_type: "job_opening.created").order(:created_at).last
    expect(opening.fetch(:job_posting_ids)).to be_empty
    expect(opening.fetch(:metadata)).to include(
      "ingress_interface" => "web/manual",
      "location_wording" => "Europe",
      "remote_policy_wording" => "Remote",
      "compensation_original_text" => "€90k-€110k"
    )
    expect(opening.fetch(:metadata)).not_to have_key("manual_notes")
    expect(event.data).to include(
      "notes" => "Introduced by a recruiter",
      "workspace_id" => organization.typed_id
    )
  end

  it "captures URL evidence, infers a known source, and does not fork an existing posting" do
    request_params = {
      title: "Senior Ruby Developer",
      company_name: "Example Product",
      url: "https://jobs.dou.ua/companies/example/vacancies/123/#details",
      location: "Ukraine",
      idempotency_key: "manual-url-1"
    }

    post openings_path, params: request_params

    opening = redirected_opening
    expect(opening.fetch(:job_posting_ids).size).to eq(1)
    posting = MarketCatalog::Api.fetch_posting(posting_id: opening.fetch(:job_posting_ids).first)
    expect(posting.fetch(:source_key)).to eq("dou")
    expect(posting.fetch(:canonical_url)).to eq("https://jobs.dou.ua/companies/example/vacancies/123/")
    expect(posting.fetch(:metadata)).to include(
      "ingress_interface" => "web/manual",
      "source_host" => "jobs.dou.ua"
    )
    expect(posting.fetch(:metadata)).not_to have_key("submitted_by_workspace")

    expect do
      post openings_path, params: request_params.merge(idempotency_key: "manual-url-2")
    end.to change(
      Platform::DomainEvent.where(event_type: "job_opening.manual_submission_recorded"), :count
    ).by(1).and change(
      Platform::DomainEvent.where(event_type: "job_opening.created"), :count
    ).by(0)

    repeated = redirected_opening
    expect(repeated.fetch(:id)).to eq(opening.fetch(:id))
    expect(repeated.fetch(:job_posting_ids)).to eq(opening.fetch(:job_posting_ids))
  end

  it "replays the same manual command without duplicating canonical state" do
    request_params = {
      title: "Staff Backend Engineer",
      idempotency_key: "manual-idempotent-1"
    }

    post openings_path, params: request_params
    first_location = response.headers.fetch("Location")
    first_opening = redirected_opening

    expect do
      post openings_path, params: request_params
    end.to change(Platform::DomainEvent, :count).by(0)
      .and change(Platform::OutboxMessage, :count).by(0)

    expect(response).to have_http_status(:see_other)
    expect(response.headers.fetch("Location")).to eq(first_location)
    expect(redirected_opening.fetch(:id)).to eq(first_opening.fetch(:id))
  end

  private

  def redirected_opening
    expect(response).to have_http_status(:see_other)
    opening_id = response.headers.fetch("Location").split("/").last
    MarketCatalog::Api.fetch_opening(opening_id:)
  end
end
