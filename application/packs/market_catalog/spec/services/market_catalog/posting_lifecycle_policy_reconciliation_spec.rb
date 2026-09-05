# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Versioned posting lifecycle policy", type: :model do
  let(:base_time) { Time.zone.parse("2026-09-05 09:00:00") }

  def create_posting(external_id:)
    MarketCatalog::RecordPosting.call(
      source_key: "dou",
      external_id:,
      title: "Senior Ruby Engineer",
      observed_at: base_time
    )
  end

  def create_opening
    MarketCatalog::CreateOpening.call(
      canonical_title: "Senior Ruby Engineer",
      first_seen_at: base_time
    )
  end

  def link(posting, opening)
    MarketCatalog::ResolvePostingOpeningLink.call(
      posting_id: posting.typed_id,
      opening_id: opening.typed_id,
      confidence: 1.0,
      evidence: [ { "kind" => "deterministic_test" } ],
      resolver_key: "spec",
      resolver_version: "v1",
      decided_at: base_time
    )
  end

  def missing(posting, number)
    MarketCatalog::RecordPostingSnapshot.call(
      posting_id: posting.typed_id,
      source_observation_id: TypeID.from_uuid("source_observation", SecureRandom.uuid).to_s,
      observed_at: base_time + number.hours,
      presence_state: "missing",
      normalizer_key: "dou_job_posting",
      normalizer_version: "v1"
    )
  end

  def present(posting, number)
    MarketCatalog::RecordPostingSnapshot.call(
      posting_id: posting.typed_id,
      source_observation_id: TypeID.from_uuid("source_observation", SecureRandom.uuid).to_s,
      observed_at: base_time + number.hours,
      presence_state: "present",
      normalizer_key: "dou_job_posting",
      normalizer_version: "v1"
    )
  end

  it "promotes three consecutive healthy absence observations to probably closed by default" do
    posting = create_posting(external_id: "probable-close")
    opening = create_opening
    link(posting, opening)

    1.upto(2) do |number|
      missing(posting, number)
      MarketCatalog::ReconcilePostingLifecycle.call(posting_id: posting.typed_id)
      expect(posting.reload.lifecycle_state).to eq("missing")
    end

    missing(posting, 3)
    MarketCatalog::ReconcilePostingLifecycle.call(posting_id: posting.typed_id)

    expect(posting.reload).to have_attributes(
      lifecycle_state: "probably_closed",
      missing_since: base_time + 1.hour
    )
    expect(posting.metadata.fetch("lifecycle_projection")).to include(
      "version" => "v1",
      "probably_closed_after_misses" => 3,
      "closed_after_misses" => nil,
      "consecutive_missing_observations" => 3
    )
    expect(opening.reload).to have_attributes(lifecycle_state: "probably_closed", closed_at: nil)
  end

  it "supports an explicitly configured inferred-close threshold and records its policy snapshot" do
    posting = create_posting(external_id: "configured-close")
    opening = create_opening
    link(posting, opening)
    policy = MarketCatalog::PostingLifecyclePolicy.new(
      version: "v1",
      probably_closed_after_misses: 2,
      closed_after_misses: 4
    )

    1.upto(4) { missing(posting, _1) }
    MarketCatalog::ReconcilePostingLifecycle.call(posting_id: posting.typed_id, policy:)

    expect(posting.reload.lifecycle_state).to eq("closed")
    expect(posting.metadata.fetch("lifecycle_projection")).to include(
      "version" => "v1",
      "probably_closed_after_misses" => 2,
      "closed_after_misses" => 4,
      "consecutive_missing_observations" => 4
    )
    expect(opening.reload).to have_attributes(
      lifecycle_state: "closed",
      closed_at: base_time + 4.hours
    )
  end

  it "resets the consecutive absence projection after a confirmed reappearance" do
    posting = create_posting(external_id: "absence-reset")

    1.upto(3) { missing(posting, _1) }
    MarketCatalog::ReconcilePostingLifecycle.call(posting_id: posting.typed_id)
    expect(posting.reload.lifecycle_state).to eq("probably_closed")

    present(posting, 4)
    MarketCatalog::ReconcilePostingLifecycle.call(posting_id: posting.typed_id)

    expect(posting.reload.lifecycle_state).to eq("reappeared")
    expect(posting.metadata.dig("lifecycle_projection", "consecutive_missing_observations")).to eq(0)
  end
end
