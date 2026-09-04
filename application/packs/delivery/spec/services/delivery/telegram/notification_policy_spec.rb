# frozen_string_literal: true

require "rails_helper"

RSpec.describe Delivery::Telegram::NotificationPolicy do
  it "always delivers legacy posting notifications" do
    payload = {
      "event_type" => "JobPostingDiscovered",
      "title" => "Senior Ruby Engineer"
    }

    expect(described_class.deliver?(payload, action_priority_threshold: 80)).to be(true)
  end

  it "delivers assessed opportunities at or above the configured action-priority threshold" do
    payload = {
      "notification_kind" => "opportunity_assessed",
      "action_priority" => 80.0
    }

    expect(described_class.deliver?(payload, action_priority_threshold: 80)).to be(true)
  end

  it "suppresses assessed opportunities below the configured action-priority threshold" do
    payload = {
      "notification_kind" => "opportunity_assessed",
      "action_priority" => 79.9
    }

    expect(described_class.deliver?(payload, action_priority_threshold: 80)).to be(false)
  end

  it "suppresses assessed opportunities without an action priority" do
    payload = { "notification_kind" => "opportunity_assessed" }

    expect(described_class.deliver?(payload, action_priority_threshold: 80)).to be(false)
  end
end
