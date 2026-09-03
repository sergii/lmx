# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarketCatalog::RecordPosting, type: :model do
  let(:observed_at) { Time.zone.parse("2026-09-02 00:15:00") }
  let(:company) { MarketCatalog::CreateCompany.call(canonical_name: "Example") }
  let(:attributes) do
    {
      source_key: "dou",
      external_id: "vacancies/123",
      canonical_url: "https://jobs.dou.ua/companies/example/vacancies/123/",
      application_url: "https://example.test/apply/123",
      title: "Senior Ruby Engineer",
      publisher_company_id: company.typed_id,
      observed_at:,
      metadata: { "collector" => "dou-v1" }
    }
  end

  it "deduplicates the same source posting by external ID" do
    first = described_class.call(**attributes)

    expect do
      second = described_class.call(**attributes.merge(observed_at: observed_at + 5.minutes))
      expect(second.id).to eq(first.id)
      expect(second.last_confirmed_present_at).to eq(observed_at + 5.minutes)
    end.not_to change(MarketCatalog::JobPosting, :count)
  end

  it "deduplicates by canonical posting URL when external ID is initially absent" do
    first = described_class.call(**attributes.except(:external_id))
    second = described_class.call(**attributes.merge(observed_at: observed_at + 1.minute))

    expect(second.id).to eq(first.id)
    expect(second.external_id).to eq("vacancies/123")
  end

  it "never merges postings merely because company and title match" do
    first = described_class.call(**attributes)
    second = described_class.call(
      **attributes.merge(
        external_id: "vacancies/456",
        canonical_url: "https://jobs.dou.ua/companies/example/vacancies/456/",
        application_url: "https://example.test/apply/456"
      )
    )

    expect(second.id).not_to eq(first.id)
    expect(MarketCatalog::JobPosting.count).to eq(2)
  end

  it "raises when strong identity signals point to different postings" do
    first = described_class.call(**attributes)
    second = described_class.call(
      **attributes.merge(
        external_id: "vacancies/456",
        canonical_url: "https://jobs.dou.ua/companies/example/vacancies/456/",
        application_url: "https://example.test/apply/456"
      )
    )

    expect do
      described_class.call(
        **attributes.merge(
          external_id: first.external_id,
          canonical_url: second.canonical_url,
          application_url: nil,
          observed_at: observed_at + 2.minutes
        )
      )
    end.to raise_error(MarketCatalog::RecordPosting::IdentityConflict)
  end

  it "does not let out-of-order replay regress current title" do
    posting = described_class.call(**attributes)
    posting = described_class.call(
      **attributes.merge(title: "Principal Ruby Engineer", observed_at: observed_at + 10.minutes)
    )

    replayed = described_class.call(
      **attributes.merge(title: "Old Ruby Engineer", observed_at: observed_at - 10.minutes)
    )

    expect(replayed.id).to eq(posting.id)
    expect(replayed.title).to eq("Principal Ruby Engineer")
    expect(replayed.first_seen_at).to eq(observed_at - 10.minutes)
    expect(replayed.last_confirmed_present_at).to eq(observed_at + 10.minutes)
  end

  it "records reappearance without treating absence as proof of closure" do
    posting = described_class.call(**attributes)
    posting.update!(lifecycle_state: "missing", missing_since: observed_at + 1.minute)

    seen_again = described_class.call(**attributes.merge(observed_at: observed_at + 5.minutes))

    expect(seen_again.lifecycle_state).to eq("reappeared")
    expect(seen_again.missing_since).to be_nil
  end
end
