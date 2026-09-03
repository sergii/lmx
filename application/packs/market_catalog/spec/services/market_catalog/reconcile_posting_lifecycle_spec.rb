# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarketCatalog::ReconcilePostingLifecycle, type: :model do
  let(:base_time) { Time.zone.parse("2026-09-02 10:00:00") }

  def create_opening(title: "Senior Ruby Engineer")
    MarketCatalog::CreateOpening.call(canonical_title: title, first_seen_at: base_time)
  end

  def create_posting(external_id:, observed_at: base_time)
    MarketCatalog::RecordPosting.call(
      source_key: "dou",
      external_id:,
      title: "Senior Ruby Engineer",
      observed_at:
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

  def record_snapshot(posting, presence_state:, observed_at:)
    MarketCatalog::RecordPostingSnapshot.call(
      posting_id: posting.typed_id,
      source_observation_id: TypeID.from_uuid("source_observation", SecureRandom.uuid).to_s,
      observed_at:,
      presence_state:,
      normalizer_key: "dou_job_posting",
      normalizer_version: "v1"
    )
  end

  it "projects a missing observation without manufacturing closure" do
    opening = create_opening
    posting = create_posting(external_id: "missing-once")
    link(posting, opening)
    missing_at = base_time + 1.hour
    record_snapshot(posting, presence_state: "missing", observed_at: missing_at)

    described_class.call(posting_id: posting.typed_id)

    expect(posting.reload).to have_attributes(
      lifecycle_state: "missing",
      missing_since: missing_at,
      last_confirmed_present_at: base_time
    )
    expect(opening.reload).to have_attributes(lifecycle_state: "missing", closed_at: nil)
  end

  it "keeps an explicit closure authoritative through later missing observations" do
    opening = create_opening
    posting = create_posting(external_id: "explicit-close")
    link(posting, opening)
    missing_at = base_time + 1.hour
    closed_at = base_time + 2.hours

    record_snapshot(posting, presence_state: "missing", observed_at: missing_at)
    record_snapshot(posting, presence_state: "explicit_closed", observed_at: closed_at)
    record_snapshot(posting, presence_state: "missing", observed_at: base_time + 3.hours)

    described_class.call(posting_id: posting.typed_id)

    expect(posting.reload).to have_attributes(lifecycle_state: "closed", missing_since: missing_at)
    expect(opening.reload).to have_attributes(lifecycle_state: "closed", closed_at: closed_at)
  end

  it "projects reappearance once and returns to present after continuous presence" do
    opening = create_opening
    posting = create_posting(external_id: "reappears")
    link(posting, opening)

    record_snapshot(posting, presence_state: "missing", observed_at: base_time + 1.hour)
    described_class.call(posting_id: posting.typed_id)
    expect(posting.reload.lifecycle_state).to eq("missing")

    record_snapshot(posting, presence_state: "present", observed_at: base_time + 2.hours)
    described_class.call(posting_id: posting.typed_id)
    expect(posting.reload).to have_attributes(lifecycle_state: "reappeared", missing_since: nil)
    expect(opening.reload).to have_attributes(lifecycle_state: "reopened", closed_at: nil)

    record_snapshot(posting, presence_state: "present", observed_at: base_time + 3.hours)
    described_class.call(posting_id: posting.typed_id)
    expect(posting.reload).to have_attributes(
      lifecycle_state: "present",
      last_confirmed_present_at: base_time + 3.hours,
      missing_since: nil
    )
    expect(opening.reload.lifecycle_state).to eq("open")
  end

  it "does not let an out-of-order older absence override newer confirmed presence" do
    opening = create_opening
    posting = create_posting(external_id: "out-of-order", observed_at: base_time + 3.hours)
    link(posting, opening)

    record_snapshot(posting, presence_state: "missing", observed_at: base_time + 2.hours)
    described_class.call(posting_id: posting.typed_id)

    expect(posting.reload).to have_attributes(
      lifecycle_state: "present",
      last_confirmed_present_at: base_time + 3.hours,
      missing_since: nil
    )
    expect(opening.reload.lifecycle_state).to eq("open")
  end

  it "keeps an opening open while any linked posting remains present" do
    opening = create_opening
    first_posting = create_posting(external_id: "multi-source-1")
    second_posting = create_posting(external_id: "multi-source-2")
    link(first_posting, opening)
    link(second_posting, opening)

    record_snapshot(first_posting, presence_state: "explicit_closed", observed_at: base_time + 1.hour)
    described_class.call(posting_id: first_posting.typed_id)

    expect(first_posting.reload.lifecycle_state).to eq("closed")
    expect(opening.reload).to have_attributes(lifecycle_state: "open", closed_at: nil)

    record_snapshot(second_posting, presence_state: "explicit_closed", observed_at: base_time + 2.hours)
    described_class.call(posting_id: second_posting.typed_id)

    expect(second_posting.reload.lifecycle_state).to eq("closed")
    expect(opening.reload).to have_attributes(lifecycle_state: "closed", closed_at: base_time + 2.hours)
  end

  it "ignores unknown evidence" do
    posting = create_posting(external_id: "unknown")
    record_snapshot(posting, presence_state: "unknown", observed_at: base_time + 1.hour)

    described_class.call(posting_id: posting.typed_id)

    expect(posting.reload).to have_attributes(
      lifecycle_state: "present",
      last_confirmed_present_at: base_time,
      missing_since: nil
    )
  end

  it "reconciles a newly linked opening from the posting's current lifecycle" do
    posting = create_posting(external_id: "link-after-close")
    record_snapshot(posting, presence_state: "explicit_closed", observed_at: base_time + 1.hour)
    described_class.call(posting_id: posting.typed_id)
    expect(posting.reload.lifecycle_state).to eq("closed")

    opening = create_opening
    link(posting, opening)

    expect(opening.reload).to have_attributes(
      lifecycle_state: "closed",
      closed_at: base_time + 1.hour
    )
  end
end
