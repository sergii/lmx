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
    expect(response.body).to include('"key":"dou"')
    expect(response.body).to include('"opportunity_score":92.0')
    expect(response.body).to include('"action_priority":87.0')
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
    expect(response.body).to include('"candidate":null')
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
    end.to change(MarketCatalog::JobOpening, :count).by(1)
      .and change(Platform::DomainEvent.where(event_type: "job_opening.created"), :count).by(1)
      .and change(Platform::OutboxMessage.where(message_type: "job_opening.created"), :count).by(1)

    opening = MarketCatalog::JobOpening.order(:created_at).last
    expect(response).to redirect_to(opening_path(opening.typed_id))
    expect(opening.job_postings).to be_empty
    expect(opening.metadata).to include(
      "ingress_interface" => "web/manual",
      "location_wording" => "Europe",
      "remote_policy_wording" => "Remote",
      "compensation_original_text" => "€90k-€110k",
      "manual_notes" => "Introduced by a recruiter"
    )
  end

  it "captures URL evidence, infers a known source, and does not fork an existing posting" do
    params = {
      title: "Senior Ruby Developer",
      company_name: "Example Product",
      url: "https://jobs.dou.ua/companies/example/vacancies/123/#details",
      location: "Ukraine",
      idempotency_key: "manual-url-1"
    }

    expect do
      post openings_path, params:
    end.to change(MarketCatalog::JobOpening, :count).by(1)
      .and change(MarketCatalog::JobPosting, :count).by(1)

    opening = MarketCatalog::JobOpening.order(:created_at).last
    posting = opening.job_postings.first
    expect(posting.source_key).to eq("dou")
    expect(posting.canonical_url).to eq("https://jobs.dou.ua/companies/example/vacancies/123/")
    expect(posting.metadata).to include(
      "ingress_interface" => "web/manual",
      "source_host" => "jobs.dou.ua"
    )

    expect do
      post openings_path, params: params.merge(idempotency_key: "manual-url-2")
    end.to change(MarketCatalog::JobOpening, :count).by(0)
      .and change(MarketCatalog::JobPosting, :count).by(0)
      .and change(
        Platform::DomainEvent.where(event_type: "job_opening.manual_submission_recorded"), :count
      ).by(1)

    expect(response).to redirect_to(opening_path(opening.typed_id))
  end

  it "replays the same manual command without duplicating canonical state" do
    params = {
      title: "Staff Backend Engineer",
      idempotency_key: "manual-idempotent-1"
    }

    post openings_path, params:

    expect do
      post openings_path, params:
    end.to change(MarketCatalog::JobOpening, :count).by(0)
      .and change(Platform::DomainEvent, :count).by(0)
      .and change(Platform::OutboxMessage, :count).by(0)
  end
end
