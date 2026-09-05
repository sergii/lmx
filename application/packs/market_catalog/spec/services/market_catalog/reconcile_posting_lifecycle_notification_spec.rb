# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Market catalog lifecycle Telegram event classification", type: :model do
  let(:base_time) { Time.zone.parse("2026-09-02 10:00:00") }

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

  it "emits one repost-or-reopen change when presence returns after confirmed absence" do
    posting = MarketCatalog::RecordPosting.call(
      source_key: "dou",
      external_id: "reopen-notification",
      title: "Senior Ruby Engineer",
      observed_at: base_time
    )
    record_snapshot(posting, presence_state: "missing", observed_at: base_time + 1.hour)
    MarketCatalog::ReconcilePostingLifecycle.call(posting_id: posting.typed_id)
    record_snapshot(posting, presence_state: "present", observed_at: base_time + 2.hours)
    allow(MarketCatalog::EmitPostingEvent).to receive(:call)

    MarketCatalog::ReconcilePostingLifecycle.call(posting_id: posting.typed_id)

    expect(MarketCatalog::EmitPostingEvent).to have_received(:call).with(
      posting: an_object_having_attributes(id: posting.id),
      event_type: "JobPostingLifecycleChanged",
      occurred_at: base_time + 2.hours,
      change_kinds: [ "repost_or_reopen" ]
    ).once
  end
end
