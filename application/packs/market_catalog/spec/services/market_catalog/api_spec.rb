# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarketCatalog::Api, type: :model do
  let(:observed_at) { Time.zone.parse("2026-09-02 10:30:00") }

  it "exposes typed immutable records without leaking Active Record models" do
    company = described_class.create_company(
      canonical_name: "Example Labs",
      website_url: "https://example.test"
    )
    opening = described_class.create_opening(
      canonical_title: "Senior Ruby Engineer",
      primary_company_id: company.fetch(:id),
      first_seen_at: observed_at
    )
    posting = described_class.record_posting(
      source_key: "dou",
      external_id: "vacancies/123",
      canonical_url: "https://jobs.dou.ua/companies/example/vacancies/123/",
      title: "Senior Ruby Engineer",
      observed_at:
    )
    decision = described_class.resolve_posting_opening_link(
      posting_id: posting.fetch(:id),
      opening_id: opening.fetch(:id),
      confidence: 0.99,
      evidence: [ { "kind" => "source_external_id" } ],
      resolver_key: "deterministic",
      resolver_version: "v1",
      decided_at: observed_at
    )

    expect(company).to be_frozen
    expect(opening).to be_frozen
    expect(posting).to be_frozen
    expect(decision).to be_frozen
    expect(company.fetch(:id)).to start_with("company_")
    expect(opening.fetch(:primary_company_id)).to eq(company.fetch(:id))
    expect(decision.fetch(:job_posting_id)).to eq(posting.fetch(:id))
    expect(decision.fetch(:to_job_opening_id)).to eq(opening.fetch(:id))
    expect(company).not_to be_a(ActiveRecord::Base)
  end

  it "exposes immutable posting history using opaque SourceObservation identities" do
    posting = described_class.record_posting(
      source_key: "dou",
      external_id: "vacancies/456",
      canonical_url: "https://jobs.dou.ua/companies/example/vacancies/456/",
      title: "Ruby Engineer",
      observed_at:
    )
    source_observation_id = TypeID.from_uuid("source_observation", SecureRandom.uuid).to_s

    snapshot = described_class.record_posting_snapshot(
      posting_id: posting.fetch(:id),
      source_observation_id:,
      observed_at:,
      presence_state: "present",
      normalizer_key: "dou_job_posting",
      normalizer_version: "v1",
      title: "Ruby Engineer",
      facts: { "location" => { "value" => "Kyiv", "evidence_level" => "LISTED" } }
    )

    history = described_class.fetch_posting_history(posting_id: posting.fetch(:id))
    fetched = described_class.fetch_posting_snapshot(posting_snapshot_id: snapshot.fetch(:id))

    expect(snapshot).to be_frozen
    expect(snapshot.fetch(:facts)).to be_frozen
    expect(snapshot.fetch(:source_observation_id)).to eq(source_observation_id)
    expect(history).to eq([ snapshot ])
    expect(history).to be_frozen
    expect(fetched).to eq(snapshot)
  end

  it "returns reconciled lifecycle projections as immutable public records" do
    posting = described_class.record_posting(
      source_key: "dou",
      external_id: "vacancies/closed",
      title: "Ruby Engineer",
      observed_at:
    )
    described_class.record_posting_snapshot(
      posting_id: posting.fetch(:id),
      source_observation_id: TypeID.from_uuid("source_observation", SecureRandom.uuid).to_s,
      observed_at: observed_at + 1.hour,
      presence_state: "explicit_closed",
      normalizer_key: "dou_job_posting",
      normalizer_version: "v1"
    )

    reconciled = described_class.reconcile_posting_lifecycle(posting_id: posting.fetch(:id))

    expect(reconciled).to be_frozen
    expect(reconciled).to include(
      id: posting.fetch(:id),
      lifecycle_state: "closed",
      missing_since: observed_at + 1.hour
    )
  end

  it "returns opening parties and posting references through the public read boundary" do
    company = MarketCatalog::CreateCompany.call(canonical_name: "Vendor Inc")
    opening = MarketCatalog::CreateOpening.call(
      canonical_title: "Backend Engineer",
      first_seen_at: observed_at
    )
    party = MarketCatalog::OpeningParty.create!(
      job_opening: opening,
      company:,
      role: "staffing_vendor",
      confidence: 0.9,
      evidence: [ { "kind" => "listed" } ]
    )
    posting = MarketCatalog::RecordPosting.call(
      source_key: "djinni",
      external_id: "12345",
      title: "Backend Engineer",
      observed_at:
    )
    MarketCatalog::ResolvePostingOpeningLink.call(
      posting_id: posting.id,
      opening_id: opening.id,
      confidence: 0.95,
      evidence: [ { "kind" => "manual_review" } ],
      resolver_key: "review",
      resolver_version: "v1"
    )

    result = described_class.fetch_opening(opening_id: opening.typed_id)

    expect(result.fetch(:parties)).to contain_exactly(
      include(
        id: party.typed_id,
        company_id: company.typed_id,
        role: "staffing_vendor"
      )
    )
    expect(result.fetch(:job_posting_ids)).to eq([ posting.typed_id ])
  end

  it "normalizes missing or invalid read identifiers to the public not-found error" do
    expect do
      described_class.fetch_opening(opening_id: "opening_missing")
    end.to raise_error(described_class::NotFound, "resource not found")

    expect do
      described_class.fetch_company(company_id: "not-a-company-id")
    end.to raise_error(described_class::NotFound, "resource not found")
  end
end
