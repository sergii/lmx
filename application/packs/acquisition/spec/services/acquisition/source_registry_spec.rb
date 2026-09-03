# frozen_string_literal: true

require "rails_helper"

RSpec.describe Acquisition::SourceRegistry, type: :model do
  it "exposes configured source identifiers and acquisition strategies" do
    expect(described_class.source_ids).to eq(
      [ "dou", "djinni", "work_ua", "robota_ua", "remoteok", "remote_rails", "ruby_on_rails_jobs" ]
    )
    expect(described_class.enabled?("dou")).to be(true)
    expect(described_class.enabled?("remoteok")).to be(true)
    expect(described_class.enabled?("ruby_on_rails_jobs")).to be(false)
    expect(described_class.primary_strategy("dou")).to eq(
      "type" => "rss",
      "preference" => "primary",
      "status" => "active"
    )
    expect(described_class.primary_strategy("djinni")).to eq(
      "type" => "rss",
      "preference" => "primary",
      "status" => "active"
    )
    expect(described_class.primary_strategy("work_ua")).to eq(
      "type" => "http_html",
      "preference" => "primary",
      "status" => "active"
    )
    expect(described_class.primary_strategy("robota_ua")).to eq(
      "type" => "http_api",
      "preference" => "primary",
      "status" => "active"
    )
    expect(described_class.primary_strategy("remoteok")).to eq(
      "type" => "http_api",
      "preference" => "primary",
      "status" => "active"
    )
  end

  it "keeps objective catalog metadata separate from personal ranking policy" do
    dou = described_class.fetch("dou")
    remote_rails = described_class.fetch("remote_rails")
    retired = described_class.fetch("ruby_on_rails_jobs")

    expect(dou).to include(
      "kind" => "job_board",
      "coverage" => { "scope" => "focused", "domains" => [ "technology" ] },
      "lifecycle" => { "status" => "active" }
    )
    expect(remote_rails).to include(
      "kind" => "job_board",
      "coverage" => {
        "scope" => "focused",
        "technologies" => [ "ruby", "rails" ],
        "work_modes" => [ "remote" ]
      },
      "lifecycle" => { "status" => "evaluating" }
    )
    expect(retired.dig("lifecycle", "status")).to eq("retired")
    expect(retired).not_to have_key("specialties")

    described_class.source_ids.each do |source_id|
      source = described_class.fetch(source_id)
      expect(source).not_to have_key("weight")
      expect(source).not_to have_key("lane")
    end
  end

  it "fails explicitly for an unknown source" do
    expect { described_class.fetch("missing") }
      .to raise_error(KeyError, /Unknown acquisition source/)
  end
end
