# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarketCatalog::ReconcileSourceObservation, type: :model do
  it "materializes one source observation into an idempotent canonical opening" do
    observed_at = Time.zone.parse("2026-09-07 12:00:00")
    observation_id = TypeID.from_uuid("source_observation", SecureRandom.uuid).to_s
    observation = {
      id: observation_id,
      source_key: "work_ua",
      transport: "http_scrape",
      external_id: "123456",
      canonical_url: "https://www.work.ua/jobs/123456/",
      observed_at:,
      source_published_at: observed_at - 1.hour,
      presence_state: "present",
      parser_version: "work-ua-listing-v1",
      content_digest: "a" * 64,
      payload: {
        "record_type" => "job_posting",
        "source" => "work_ua",
        "source_record_key" => "123456",
        "url" => "https://www.work.ua/jobs/123456/",
        "title" => "Senior Ruby on Rails Engineer",
        "company_name" => "Acme",
        "location_text" => "Kyiv",
        "summary" => "Rails and PostgreSQL"
      },
      metadata: {}
    }

    first = nil
    expect do
      first = described_class.call(observation:)
    end.to change(MarketCatalog::JobOpening, :count).by(1)
      .and change(MarketCatalog::JobPosting, :count).by(1)
      .and change(MarketCatalog::PostingSnapshot, :count).by(1)
      .and change(MarketCatalog::Company, :count).by(1)

    counts_before_retry = {
      openings: MarketCatalog::JobOpening.count,
      postings: MarketCatalog::JobPosting.count,
      snapshots: MarketCatalog::PostingSnapshot.count,
      companies: MarketCatalog::Company.count
    }

    second = described_class.call(observation:)

    expect(
      openings: MarketCatalog::JobOpening.count,
      postings: MarketCatalog::JobPosting.count,
      snapshots: MarketCatalog::PostingSnapshot.count,
      companies: MarketCatalog::Company.count
    ).to eq(counts_before_retry)
    expect(second).to eq(first)

    opening = MarketCatalog::JobOpening.find_by_typed_id!(first.fetch(:opening_id))
    posting = MarketCatalog::JobPosting.find_by_typed_id!(first.fetch(:posting_id))
    snapshot = MarketCatalog::PostingSnapshot.find_by_typed_id!(first.fetch(:posting_snapshot_id))

    expect(opening.canonical_title).to eq("Senior Ruby on Rails Engineer")
    expect(opening.primary_company.canonical_name).to eq("Acme")
    expect(posting.job_opening).to eq(opening)
    expect(posting.source_key).to eq("work_ua")
    expect(posting.external_id).to eq("123456")
    expect(snapshot.source_observation_id).to eq(TypeID.from_string(observation_id).uuid.to_s)
    expect(snapshot.facts.dig("source_payload", "location_text")).to eq("Kyiv")
  end

  it "rejects evidence that is not a present job posting" do
    observation = {
      id: TypeID.from_uuid("source_observation", SecureRandom.uuid).to_s,
      source_key: "dou",
      presence_state: "unknown",
      observed_at: Time.current,
      payload: { "record_type" => "job_posting", "source" => "dou", "title" => "Ruby Engineer" }
    }

    expect { described_class.call(observation:) }
      .to raise_error(described_class::InvalidObservation, /only present job-posting observations/)
  end
end
