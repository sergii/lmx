# frozen_string_literal: true

require "rails_helper"

RSpec.describe Delivery::Telegram::Formatter do
  it "formats discovered postings as compact Telegram messages" do
    text = described_class.call(
      {
        "event_type" => "JobPostingDiscovered",
        "change_kinds" => [ "new_posting" ],
        "title" => "Senior Ruby Engineer",
        "source_key" => "dou",
        "canonical_url" => "https://jobs.dou.ua/example"
      }
    )

    expect(text).to eq("🆕 Senior Ruby Engineer\nDOU\nhttps://jobs.dou.ua/example")
  end

  it "links to the canonical LMX opening when a public base URL and opening identity are available" do
    text = described_class.call(
      {
        "event_type" => "JobPostingDiscovered",
        "change_kinds" => [ "new_posting" ],
        "title" => "Senior Ruby Engineer",
        "source_key" => "dou",
        "job_opening_id" => "opening_01k00000000000000000000000",
        "canonical_url" => "https://jobs.dou.ua/example"
      },
      public_base_url: "https://lmx.example.test/"
    )

    expect(text).to eq(
      "🆕 Senior Ruby Engineer\nDOU\nhttps://lmx.example.test/openings/opening_01k00000000000000000000000"
    )
  end

  it "formats material posting changes distinctly" do
    text = described_class.call(
      {
        "event_type" => "JobPostingUpdated",
        "change_kinds" => [ "material_posting_change" ],
        "title" => "Principal Ruby Engineer",
        "source_key" => "work_ua",
        "application_url" => "https://example.test/apply"
      }
    )

    expect(text).to eq(
      "✏️ Principal Ruby Engineer\nPosting changed\nWORK_UA\nhttps://example.test/apply"
    )
  end

  it "makes compensation changes visually explicit" do
    text = described_class.call(
      {
        "event_type" => "JobPostingUpdated",
        "change_kinds" => [ "material_posting_change", "compensation_change" ],
        "title" => "Senior Ruby Engineer",
        "source_key" => "remoteok",
        "canonical_url" => "https://remoteok.com/example"
      }
    )

    expect(text).to eq(
      "💰 Senior Ruby Engineer\nCompensation changed\nREMOTEOK\nhttps://remoteok.com/example"
    )
  end

  it "makes repost or reopen changes visually explicit" do
    text = described_class.call(
      {
        "event_type" => "JobPostingLifecycleChanged",
        "change_kinds" => [ "repost_or_reopen" ],
        "title" => "Senior Ruby Engineer",
        "source_key" => "dou",
        "canonical_url" => "https://jobs.dou.ua/example"
      }
    )

    expect(text).to eq(
      "♻️ Senior Ruby Engineer\nReopened or reposted\nDOU\nhttps://jobs.dou.ua/example"
    )
  end

  it "formats a high-priority candidate-aware opportunity with decision context" do
    text = described_class.call(
      {
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
      }
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
