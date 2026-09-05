# frozen_string_literal: true

require "rails_helper"

RSpec.describe Delivery::Telegram::NotificationPolicy do
  let(:profile) do
    {
      "source_priorities" => {
        "dou" => { "lane" => "local_fast" },
        "remoteok" => { "lane" => "remote_specialized" }
      },
      "notification" => {
        "action_priority_threshold" => 80,
        "prefer_near_real_time_for" => %w[
          new_local_fast_opportunity
          high_action_priority
          material_posting_change
          compensation_change
          repost_or_reopen
        ]
      }
    }
  end

  it "delivers newly discovered postings only when their profile lane is local-fast" do
    local = {
      "event_type" => "JobPostingDiscovered",
      "change_kinds" => [ "new_posting" ],
      "source_key" => "dou"
    }
    remote = local.merge("source_key" => "remoteok")

    expect(described_class.deliver?(local, profile:)).to be(true)
    expect(described_class.deliver?(remote, profile:)).to be(false)
  end

  it "delivers configured material, compensation, and reopen changes" do
    %w[material_posting_change compensation_change repost_or_reopen].each do |kind|
      payload = {
        "event_type" => "JobPostingUpdated",
        "change_kinds" => [ kind ],
        "source_key" => "remoteok"
      }

      expect(described_class.deliver?(payload, profile:)).to be(true)
    end
  end

  it "suppresses posting change kinds that are not selected by the profile" do
    payload = {
      "event_type" => "JobPostingLifecycleChanged",
      "change_kinds" => [ "lifecycle_change" ],
      "source_key" => "dou"
    }

    expect(described_class.deliver?(payload, profile:)).to be(false)
  end

  it "delivers assessed opportunities at or above the configured action-priority threshold" do
    payload = {
      "notification_kind" => "opportunity_assessed",
      "action_priority" => 80.0
    }

    expect(described_class.deliver?(payload, profile:)).to be(true)
  end

  it "suppresses assessed opportunities below the configured action-priority threshold" do
    payload = {
      "notification_kind" => "opportunity_assessed",
      "action_priority" => 79.9
    }

    expect(described_class.deliver?(payload, profile:)).to be(false)
  end

  it "suppresses assessed opportunities without an action priority" do
    payload = { "notification_kind" => "opportunity_assessed" }

    expect(described_class.deliver?(payload, profile:)).to be(false)
  end

  it "keeps the legacy permissive posting behavior when no notification preferences are configured" do
    payload = {
      "event_type" => "JobPostingDiscovered",
      "title" => "Senior Ruby Engineer"
    }

    expect(described_class.deliver?(payload, profile: {})).to be(true)
  end
end
