# frozen_string_literal: true

require "rails_helper"

RSpec.describe Delivery::Telegram::Publisher do
  let(:client) { instance_double(Delivery::Telegram::Client) }
  let(:now) { Time.zone.parse("2026-09-03 13:00:00") }
  let(:posting_message) do
    {
      id: "outbox_01k00000000000000000000000",
      payload: {
        "event_type" => "JobPostingDiscovered",
        "change_kinds" => [ "new_posting" ],
        "title" => "Senior Ruby Engineer",
        "source_key" => "dou",
        "canonical_url" => "https://jobs.dou.ua/example"
      }
    }
  end
  let(:opportunity_message) do
    {
      id: "outbox_01k00000000000000000000001",
      payload: {
        "notification_kind" => "opportunity_assessed",
        "title" => "Senior Ruby Engineer",
        "action_priority" => 94.0,
        "opportunity_score" => 88.5,
        "recommendation" => "Apply now"
      }
    }
  end

  it "publishes claimed Telegram messages and marks them delivered" do
    allow(Platform::Reliability::OutboxClaims).to receive(:claim).and_return([ posting_message ])
    allow(client).to receive(:send_message).and_return(true)
    allow(Platform::Reliability::Api).to receive(:mark_outbox_published)

    expect(described_class.call(client:, now:)).to eq(1)
    expect(Platform::Reliability::OutboxClaims).to have_received(:claim).with(
      message_types: Delivery::Telegram::Publisher::MESSAGE_TYPES,
      limit: 50,
      at: now
    )
    expect(client).to have_received(:send_message).with(
      text: "🆕 Senior Ruby Engineer\nDOU\nhttps://jobs.dou.ua/example"
    )
    expect(Platform::Reliability::Api).to have_received(:mark_outbox_published).with(
      message_id: posting_message.fetch(:id),
      published_at: now
    )
  end

  it "uses the canonical LMX opening URL when public routing context is available" do
    linked = posting_message.deep_dup
    linked[:payload]["job_opening_id"] = "opening_01k00000000000000000000000"
    allow(Platform::Reliability::OutboxClaims).to receive(:claim).and_return([ linked ])
    allow(client).to receive(:send_message).and_return(true)
    allow(Platform::Reliability::Api).to receive(:mark_outbox_published)

    described_class.call(client:, now:, public_base_url: "https://lmx.example.test")

    expect(client).to have_received(:send_message).with(
      text: "🆕 Senior Ruby Engineer\nDOU\nhttps://lmx.example.test/openings/opening_01k00000000000000000000000"
    )
  end

  it "terminally suppresses new postings outside profile-selected near-real-time lanes" do
    remote = posting_message.deep_dup
    remote[:payload]["source_key"] = "remoteok"
    profile = {
      "source_priorities" => {
        "dou" => { "lane" => "local_fast" },
        "remoteok" => { "lane" => "remote_specialized" }
      },
      "notification" => {
        "prefer_near_real_time_for" => [ "new_local_fast_opportunity" ]
      }
    }
    allow(Platform::Reliability::OutboxClaims).to receive(:claim).and_return([ remote ])
    allow(client).to receive(:send_message)
    allow(Platform::Reliability::Api).to receive(:mark_outbox_published)

    expect(described_class.call(client:, now:, profile:)).to eq(1)
    expect(client).not_to have_received(:send_message)
    expect(Platform::Reliability::Api).to have_received(:mark_outbox_published).with(
      message_id: remote.fetch(:id),
      published_at: now
    )
  end

  it "delivers candidate-aware opportunities at the configured threshold" do
    allow(Platform::Reliability::OutboxClaims).to receive(:claim).and_return([ opportunity_message ])
    allow(client).to receive(:send_message).and_return(true)
    allow(Platform::Reliability::Api).to receive(:mark_outbox_published)

    expect(described_class.call(client:, now:, action_priority_threshold: 90)).to eq(1)
    expect(client).to have_received(:send_message).with(
      text: "🔥 Senior Ruby Engineer\nPriority 94 · Opportunity 88.5\nApply now"
    )
    expect(Platform::Reliability::Api).to have_received(:mark_outbox_published).with(
      message_id: opportunity_message.fetch(:id),
      published_at: now
    )
  end

  it "terminally suppresses low-priority opportunity notifications without sending Telegram traffic" do
    low_priority = opportunity_message.deep_dup
    low_priority[:payload]["action_priority"] = 70.0
    allow(Platform::Reliability::OutboxClaims).to receive(:claim).and_return([ low_priority ])
    allow(client).to receive(:send_message)
    allow(Platform::Reliability::Api).to receive(:mark_outbox_published)

    expect(described_class.call(client:, now:, action_priority_threshold: 80)).to eq(1)
    expect(client).not_to have_received(:send_message)
    expect(Platform::Reliability::Api).to have_received(:mark_outbox_published).with(
      message_id: low_priority.fetch(:id),
      published_at: now
    )
  end

  it "marks failed deliveries for retry without blocking the batch" do
    allow(Platform::Reliability::OutboxClaims).to receive(:claim).and_return([ posting_message ])
    allow(client).to receive(:send_message).and_raise(Delivery::Telegram::Client::Error, "boom")
    allow(Platform::Reliability::Api).to receive(:mark_outbox_failed)

    expect(described_class.call(client:, now:)).to eq(1)
    expect(Platform::Reliability::Api).to have_received(:mark_outbox_failed).with(
      message_id: posting_message.fetch(:id),
      error: { "class" => "Delivery::Telegram::Client::Error", "message" => "boom" },
      retry_at: now + 1.minute
    )
  end
end
