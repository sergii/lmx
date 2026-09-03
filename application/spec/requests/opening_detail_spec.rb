# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Opening detail", type: :request do
  let!(:user) do
    User.create!(
      name: "Ada Lovelace",
      email: "ada-opening-detail@example.com",
      password: "Password12345!",
      verified: true
    )
  end
  let!(:organization) { Organization.create!(name: "Opening detail workspace", slug: "opening-detail-workspace") }
  let!(:membership) { Membership.create!(user:, organization:, role: "workspace_admin") }

  before do
    sign_in user
  end

  it "renders canonical facts, cross-source history, assessment details, and provenance" do
    now = Time.current.change(usec: 0)
    company = MarketCatalog::Api.create_company(
      canonical_name: "Example Labs",
      website_url: "https://example.test",
      primary_domain: "example.test"
    )
    opening = MarketCatalog::Api.create_opening(
      canonical_title: "Senior Ruby Engineer",
      primary_company_id: company.fetch(:id),
      first_seen_at: now,
      metadata: {
        location: "Kyiv / Remote",
        compensation_text: "$6,000-$7,000",
        remote_policy: "Remote within Europe"
      }
    )
    posting = MarketCatalog::Api.record_posting(
      source_key: "dou",
      title: "Senior Ruby Engineer",
      observed_at: now,
      external_id: "opening-detail-1",
      canonical_url: "https://jobs.example.test/ruby",
      publisher_company_id: company.fetch(:id)
    )
    snapshot = MarketCatalog::Api.record_posting_snapshot(
      posting_id: posting.fetch(:id),
      source_observation_id: SecureRandom.uuid,
      observed_at: now,
      presence_state: "present",
      normalizer_key: "request_spec",
      normalizer_version: "1",
      title: "Senior Ruby Engineer",
      facts: {
        location: "Kyiv / Remote",
        compensation_text: "$6,000-$7,000",
        remote_policy: "Remote within Europe"
      }
    )
    MarketCatalog::Api.resolve_posting_opening_link(
      posting_id: posting.fetch(:id),
      opening_id: opening.fetch(:id),
      confidence: 1.0,
      evidence: [ "explicit request-spec link" ],
      resolver_key: "request_spec",
      resolver_version: "1"
    )

    candidate = WorkspaceContext.with(organization, membership:) do
      TalentProfile::Api.create_candidate(
        first_name: "Ada",
        last_name: "Lovelace",
        linked_user_id: user.typed_id,
        profile: { skills: [ "Ruby", "Rails", "AWS" ] }
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
        opportunity_score: 94,
        action_priority: 91,
        strengths: [ "Deep Rails experience", "Infrastructure overlap" ],
        gaps: [ "Domain ramp-up" ],
        risks: [ "Compensation needs confirmation" ],
        recommendation: "Apply through the direct source",
        interview_angles: [ "Production ownership" ],
        evidence_references: [ snapshot.fetch(:source_observation_id) ],
        processor_kind: "agent",
        processor_key: "request_spec",
        processor_version: "1"
      )
    end

    get opening_path(opening.fetch(:id))

    expect(response).to have_http_status(:success)
    expect(inertia_component).to eq("openings/show")
    expect(response.body).to include("Senior Ruby Engineer")
    expect(response.body).to include("Example Labs")
    expect(response.body).to include("Kyiv / Remote")
    expect(response.body).to include('"source_key":"dou"')
    expect(response.body).to include(snapshot.fetch(:source_observation_id))
    expect(response.body).to include("Deep Rails experience")
    expect(response.body).to include("Domain ramp-up")
    expect(response.body).to include("Compensation needs confirmation")
    expect(response.body).to include("Production ownership")
    expect(response.body).to include('"stale":false')
  end

  it "returns not found for an unknown canonical opening" do
    get opening_path(TypeID.from_uuid("opening", SecureRandom.uuid).to_s)

    expect(response).to have_http_status(:not_found)
  end
end
