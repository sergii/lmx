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

  it "formats a high-priority candidate-aware opportunity with decision context" do
    text = described_class.call(
      "notification_kind" => "opportunity_assessed",
      "title" => "Senior Ruby Engineer",
      "company_name" => "Example Labs",
      "source_key" => "dou",
      "url" => "https://jobs.dou.ua/example",
      "opportunity_score" => 88.5,
      "action_priority" => 94.0,
      "recommendation" => "Apply now",
      "strengths" => [ "deep Rails experience", "production ownership", "ignored third" ],
      "gaps" => [ "domain-specific context" ],
      "risks" => [ "compensation unknown" ],
      "interview_angles" => [ "production ownership" ]
    )

    expect(text).to eq(<<~TEXT.chomp)
      🔥 Senior Ruby Engineer @ Example Labs
      Priority 94 · Opportunity 88.5
      Apply now
      Strengths: deep Rails experience; production ownership
      Gaps: domain-specific context
      Risks: compensation unknown
      Interview: production ownership
      DOU
      https://jobs.dou.ua/example
    TEXT
  end
end
