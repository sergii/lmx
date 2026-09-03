# frozen_string_literal: true

require "rails_helper"

RSpec.describe Delivery::Telegram::Publisher do
  let(:client) { instance_double(Delivery::Telegram::Client) }
  let(:now) { Time.zone.parse("2026-09-03 13:00:00") }
  let(:message) do
    {
      id: "outbox_01k00000000000000000000000",
      payload: {
        "event_type" => "JobPostingDiscovered",
        "title" => "Senior Ruby Engineer",
        "source_key" => "dou",
        "canonical_url" => "https://jobs.dou.ua/example"
      }
    }
  end

  it "publishes claimed Telegram messages and marks them delivered" do
    allow(Platform::Reliability::OutboxClaims).to receive(:claim).and_return([ message ])
    allow(client).to receive(:send_message).and_return(true)
    allow(Platform::Reliability::Api).to receive(:mark_outbox_published)

    expect(described_class.call(client:, now:)).to eq(1)
    expect(client).to have_received(:send_message).with(
      text: "🆕 Senior Ruby Engineer\nDOU\nhttps://jobs.dou.ua/example"
    )
    expect(Platform::Reliability::Api).to have_received(:mark_outbox_published).with(
      message_id: message.fetch(:id),
      published_at: now
    )
  end

  it "marks failed deliveries for retry without blocking the batch" do
    allow(Platform::Reliability::OutboxClaims).to receive(:claim).and_return([ message ])
    allow(client).to receive(:send_message).and_raise(Delivery::Telegram::Client::Error, "boom")
    allow(Platform::Reliability::Api).to receive(:mark_outbox_failed)

    expect(described_class.call(client:, now:)).to eq(1)
    expect(Platform::Reliability::Api).to have_received(:mark_outbox_failed).with(
      message_id: message.fetch(:id),
      error: { "class" => "Delivery::Telegram::Client::Error", "message" => "boom" },
      retry_at: now + 1.minute
    )
  end
end
