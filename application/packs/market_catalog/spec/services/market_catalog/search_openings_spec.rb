# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarketCatalog::SearchOpenings, type: :model do
  let(:base_time) { Time.zone.parse("2026-09-02 10:00:00") }

  def create_opening(title:, seen_at:, company_id: nil, lifecycle_state: "open", source_key: nil)
    snapshot = MarketCatalog::Api.create_opening(
      canonical_title: title,
      primary_company_id: company_id,
      first_seen_at: seen_at
    )
    opening = MarketCatalog::JobOpening.find_by_typed_id!(snapshot.fetch(:id))
    opening.update!(lifecycle_state:) unless lifecycle_state == "open"

    if source_key
      posting = MarketCatalog::Api.record_posting(
        source_key:,
        external_id: "#{source_key}-#{opening.id}",
        title:,
        observed_at: seen_at
      )
      MarketCatalog::Api.resolve_posting_opening_link(
        posting_id: posting.fetch(:id),
        opening_id: opening.typed_id,
        confidence: 1.0,
        evidence: [ { "kind" => "test_fixture" } ],
        resolver_key: "spec",
        resolver_version: "v1",
        decided_at: seen_at
      )
    end

    opening
  end

  it "filters canonical openings without exposing acquisition or posting internals" do
    company = MarketCatalog::Api.create_company(canonical_name: "Example Labs")
    other_company = MarketCatalog::Api.create_company(canonical_name: "Other Labs")

    ruby = create_opening(
      title: "Senior Ruby Engineer",
      seen_at: base_time,
      company_id: company.fetch(:id),
      source_key: "dou"
    )
    create_opening(
      title: "Rails Platform Engineer",
      seen_at: base_time + 1.hour,
      company_id: company.fetch(:id),
      lifecycle_state: "closed",
      source_key: "dou"
    )
    create_opening(
      title: "Go Engineer",
      seen_at: base_time + 2.hours,
      company_id: other_company.fetch(:id),
      source_key: "djinni"
    )

    result = described_class.call(
      query: "  SENIOR   ruby ",
      filters: {
        lifecycle_state: "open",
        primary_company_id: company.fetch(:id),
        source_key: "DOU"
      }
    )

    expect(result.records).to eq([ ruby ])
    expect(result.records).to be_frozen
    expect(result.next_cursor).to be_nil
  end

  it "paginates in stable first-seen and UUID order using an opaque cursor" do
    oldest = create_opening(title: "Oldest", seen_at: base_time)
    middle = create_opening(title: "Middle", seen_at: base_time + 1.hour)
    newest = create_opening(title: "Newest", seen_at: base_time + 2.hours)

    first_page = described_class.call(limit: 2)
    second_page = described_class.call(limit: 2, cursor: first_page.next_cursor)

    expect(first_page.records).to eq([ newest, middle ])
    expect(first_page.next_cursor).to be_present
    expect(first_page.next_cursor).not_to include(newest.id)
    expect(second_page.records).to eq([ oldest ])
    expect(second_page.next_cursor).to be_nil
  end

  it "rejects unsupported filters, invalid limits, and invalid cursors" do
    expect { described_class.call(filters: { salary: "high" }) }
      .to raise_error(described_class::InvalidFilter, /unsupported opening filter/)
    expect { described_class.call(limit: 0) }
      .to raise_error(ArgumentError, /limit must be between/)
    expect { described_class.call(cursor: "not-a-cursor") }
      .to raise_error(described_class::InvalidCursor, /cursor is invalid/)
  end
end

RSpec.describe MarketCatalog::Api, type: :model do
  let(:base_time) { Time.zone.parse("2026-09-02 10:00:00") }

  it "exposes opening search in the Integration collection envelope shape" do
    company = described_class.create_company(canonical_name: "Example Labs")
    first = described_class.create_opening(
      canonical_title: "Senior Ruby Engineer",
      primary_company_id: company.fetch(:id),
      first_seen_at: base_time
    )
    second = described_class.create_opening(
      canonical_title: "Principal Ruby Engineer",
      primary_company_id: company.fetch(:id),
      first_seen_at: base_time + 1.hour
    )
    described_class.create_opening(
      canonical_title: "Go Engineer",
      primary_company_id: company.fetch(:id),
      first_seen_at: base_time + 2.hours
    )

    page = described_class.search_openings(query: "ruby", limit: 1)
    next_page = described_class.search_openings(query: "ruby", limit: 1, cursor: page.fetch(:next_cursor))

    expect(page.keys).to contain_exactly(:items, :next_cursor)
    expect(page.fetch(:items).map { _1.fetch(:id) }).to eq([ second.fetch(:id) ])
    expect(next_page.fetch(:items).map { _1.fetch(:id) }).to eq([ first.fetch(:id) ])
    expect(next_page).not_to have_key(:next_cursor)
    expect(page).to be_frozen
    expect(page.fetch(:items)).to be_frozen
    expect(page.fetch(:items).first).to be_frozen
    expect(page.fetch(:items).first).not_to be_a(ActiveRecord::Base)
  end
end
