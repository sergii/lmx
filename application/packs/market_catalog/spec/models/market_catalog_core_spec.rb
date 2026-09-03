# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Market Catalog core models", type: :model do
  it "keeps canonical market entities outside workspace tenancy" do
    expect(MarketCatalog::Company.column_names).not_to include("organization_id")
    expect(MarketCatalog::JobOpening.column_names).not_to include("organization_id")
    expect(MarketCatalog::JobPosting.column_names).not_to include("organization_id")
  end

  it "creates typed canonical company and opening identities" do
    company = MarketCatalog::CreateCompany.call(
      canonical_name: "  Example   Labs  ",
      website_url: "https://example.test/careers"
    )
    opening = MarketCatalog::CreateOpening.call(
      canonical_title: " Senior   Ruby Engineer ",
      primary_company_id: company.typed_id,
      first_seen_at: Time.zone.parse("2026-09-02 00:00:00")
    )

    expect(company).to have_attributes(
      canonical_name: "Example Labs",
      normalized_name: "example labs",
      primary_domain: "example.test"
    )
    expect(company.typed_id).to start_with("company_")

    expect(opening).to have_attributes(
      primary_company: company,
      canonical_title: "Senior Ruby Engineer",
      normalized_title: "senior ruby engineer",
      lifecycle_state: "open"
    )
    expect(opening.typed_id).to start_with("opening_")
  end

  it "represents an unknown end client without inventing a Company" do
    opening = MarketCatalog::CreateOpening.call(
      canonical_title: "Platform Engineer",
      first_seen_at: Time.zone.parse("2026-09-02 00:00:00")
    )

    party = MarketCatalog::OpeningParty.create!(
      job_opening: opening,
      role: "end_client",
      party_label: "US healthcare client",
      confidence: 1.0,
      evidence: [ { "kind" => "listed", "claim" => "US healthcare client" } ]
    )

    expect(party.company).to be_nil
    expect(party.party_label).to eq("US healthcare client")
    expect(party.typed_id).to start_with("opening_party_")
  end
end
