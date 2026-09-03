# frozen_string_literal: true

require "rails_helper"

RSpec.describe Delivery::Telegram::Formatter do
  it "formats discovered postings as compact Telegram messages" do
    text = described_class.call(
      "event_type" => "JobPostingDiscovered",
      "title" => "Senior Ruby Engineer",
      "source_key" => "dou",
      "canonical_url" => "https://jobs.dou.ua/example"
    )

    expect(text).to eq("🆕 Senior Ruby Engineer\nDOU\nhttps://jobs.dou.ua/example")
  end

  it "falls back to the application URL for updates" do
    text = described_class.call(
      "event_type" => "JobPostingUpdated",
      "title" => "Principal Ruby Engineer",
      "source_key" => "work_ua",
      "application_url" => "https://example.test/apply"
    )

    expect(text).to eq("✏️ Principal Ruby Engineer\nWORK_UA\nhttps://example.test/apply")
  end
end
