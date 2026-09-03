# frozen_string_literal: true

require "rails_helper"

RSpec.describe Acquisition::QueryPolicy, type: :model do
  it "returns deterministic source queries from the default profile" do
    expect(described_class.source_queries("work_ua")).to eq([ "Ruby" ])
    expect(described_class.source_queries(:robota_ua)).to eq([ "Ruby" ])
  end

  it "returns an empty query set for sources collected as complete feeds" do
    expect(described_class.source_queries("dou")).to eq([])
    expect(described_class.source_queries("djinni")).to eq([])
    expect(described_class.source_queries("remoteok")).to eq([])
  end

  it "can resolve operational queries from another search profile without changing source metadata" do
    profile = {
      "acquisition" => {
        "source_queries" => {
          "work_ua" => [ "Go", "Go", " Backend Go " ]
        }
      }
    }

    expect(described_class.source_queries("work_ua", profile:)).to eq([ "Go", "Backend Go" ])
  end
end
