# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarketCatalog::PostingLifecyclePolicy do
  it "keeps one miss non-terminal and promotes repeated misses conservatively" do
    policy = described_class.new

    expect(policy.state_for_missing_count(1)).to eq("missing")
    expect(policy.state_for_missing_count(2)).to eq("missing")
    expect(policy.state_for_missing_count(3)).to eq("probably_closed")
    expect(policy.state_for_missing_count(20)).to eq("probably_closed")
  end

  it "can enable inferred closure explicitly without weakening the single-miss guard" do
    policy = described_class.new(
      probably_closed_after_misses: 2,
      closed_after_misses: 4
    )

    expect(policy.state_for_missing_count(1)).to eq("missing")
    expect(policy.state_for_missing_count(2)).to eq("probably_closed")
    expect(policy.state_for_missing_count(4)).to eq("closed")
  end

  it "loads a named policy version and thresholds from operator configuration" do
    policy = described_class.from_env(
      env: {
        "LMX_POSTING_LIFECYCLE_POLICY_VERSION" => "v1",
        "LMX_POSTING_PROBABLY_CLOSED_AFTER_MISSES" => "4",
        "LMX_POSTING_CLOSED_AFTER_MISSES" => "8"
      }
    )

    expect(policy.snapshot).to eq(
      "version" => "v1",
      "probably_closed_after_misses" => 4,
      "closed_after_misses" => 8
    )
  end

  it "rejects unsafe or unknown policy configuration" do
    expect do
      described_class.new(probably_closed_after_misses: 1)
    end.to raise_error(ArgumentError, /at least 2/)

    expect do
      described_class.new(probably_closed_after_misses: 4, closed_after_misses: 3)
    end.to raise_error(ArgumentError, /greater than or equal/)

    expect do
      described_class.new(version: "v2")
    end.to raise_error(ArgumentError, /unsupported/)
  end
end
