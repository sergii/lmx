# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarketCatalog::EmitPostingEvent do
  let(:opening) do
    instance_double(
      MarketCatalog::JobOpening,
      typed_id: "opening_01k00000000000000000000000"
    )
  end
  let(:posting) do
    instance_double(
      MarketCatalog::JobPosting,
      typed_id: "posting_01k00000000000000000000000",
      job_opening: opening,
      source_key: "dou",
      external_id: "123",
      title: "Senior Ruby Engineer",
      canonical_url: "https://jobs.dou.ua/example",
      application_url: nil,
      source_published_at: nil,
      source_updated_at: nil,
      lifecycle_state: "present"
    )
  end

  around do |example|
    previous = ENV["LMX_PHASE0_WORKSPACE_ID"]
    ENV["LMX_PHASE0_WORKSPACE_ID"] = "org_01k00000000000000000000000"
    example.run
  ensure
    ENV["LMX_PHASE0_WORKSPACE_ID"] = previous
  end

  it "appends the domain event and classified Telegram outbox message in workspace scope" do
    allow(Workspace::Api).to receive(:with_workspace).and_yield
    allow(Platform::Reliability::AggregateVersion).to receive(:call).and_return(2)
    allow(Platform::Reliability::Api).to receive(:append_domain_event)

    described_class.call(
      posting:,
      event_type: "JobPostingUpdated",
      occurred_at: Time.zone.parse("2026-09-03 12:30:00"),
      change_kinds: %w[material_posting_change compensation_change]
    )

    expect(Platform::Reliability::Api).to have_received(:append_domain_event).with(
      hash_including(
        event_type: "JobPostingUpdated",
        aggregate_type: "JobPosting",
        aggregate_id: posting.typed_id,
        expected_aggregate_version: 2,
        data: hash_including(
          "job_opening_id" => opening.typed_id,
          "change_kinds" => %w[material_posting_change compensation_change]
        ),
        outbox_messages: [
          hash_including(
            message_type: "delivery.telegram.job_posting",
            destination: "telegram",
            payload: hash_including(
              "event_type" => "JobPostingUpdated",
              "job_opening_id" => opening.typed_id,
              "change_kinds" => %w[material_posting_change compensation_change]
            )
          )
        ]
      )
    )
  end
end
