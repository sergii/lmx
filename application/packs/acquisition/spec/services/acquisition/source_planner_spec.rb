# frozen_string_literal: true

require "rails_helper"

RSpec.describe Acquisition::SourcePlanner, type: :model do
  it "keeps catalog maturity separate from current Ruby search compatibility" do
    plan = index_by_source(described_class.plan)

    expect(Acquisition::SourceCatalog.active_source_ids).to eq(
      [ "dou", "djinni", "work_ua", "robota_ua", "remoteok" ]
    )
    expect(plan.fetch("dou")).to include(
      selected: true,
      lifecycle_status: "active",
      mismatch_dimensions: []
    )
    expect(plan.fetch("remote_rails")).to include(
      selected: false,
      lifecycle_status: "evaluating",
      mismatch_dimensions: [],
      reasons: [ "lifecycle_not_active:evaluating" ]
    )
    expect(plan.fetch("ruby_on_rails_jobs")).to include(
      selected: false,
      lifecycle_status: "retired",
      enabled: false,
      mismatch_dimensions: []
    )
    expect(plan.fetch("ruby_on_rails_jobs").fetch(:reasons)).to contain_exactly(
      "disabled",
      "lifecycle_not_active:retired"
    )
  end

  it "rejects Ruby-focused sources when the profile explicitly moves to Go" do
    profile = deep_dup(Lmx::Configuration.default_profile)
    profile["targets"] = {
      "domains" => [ "technology" ],
      "technologies" => [ "go" ],
      "roles" => [ "software_engineer", "backend_engineer" ]
    }
    profile["acquisition"]["source_queries"] = {
      "work_ua" => [ "Go" ],
      "robota_ua" => [ "Go" ]
    }

    plan = index_by_source(described_class.plan(profile:))

    expect(plan.fetch("work_ua")).to include(selected: true, queries: [ "Go" ])
    expect(plan.fetch("robota_ua")).to include(selected: true, queries: [ "Go" ])
    expect(plan.fetch("dou")).to include(selected: true, mismatch_dimensions: [])
    expect(plan.fetch("remote_rails")).to include(
      selected: false,
      mismatch_dimensions: [ "technologies" ]
    )
    expect(plan.fetch("ruby_on_rails_jobs")).to include(
      selected: false,
      mismatch_dimensions: [ "technologies" ]
    )
  end

  it "does not invent a mismatch when the profile leaves a coverage dimension unspecified" do
    profile = deep_dup(Lmx::Configuration.default_profile)
    profile["targets"] = { "domains" => [ "technology" ] }

    remote_ok = index_by_source(described_class.plan(profile:)).fetch("remoteok")

    expect(remote_ok).to include(
      selected: true,
      mismatch_dimensions: []
    )
  end

  it "returns deeply frozen planning snapshots" do
    entry = described_class.plan.first

    expect(entry).to be_frozen
    expect(entry.fetch(:coverage)).to be_frozen
    expect(entry.fetch(:reasons)).to be_frozen
    expect(entry.fetch(:queries)).to be_frozen
  end

  def index_by_source(plan)
    plan.index_by { _1.fetch(:source_id) }
  end

  def deep_dup(value)
    Marshal.load(Marshal.dump(value))
  end
end
