# frozen_string_literal: true

require "rails_helper"
require "yaml"

RSpec.describe AcquisitionCollectionJob, type: :job do
  it "routes full-feed sources through their public acquisition APIs once" do
    allow(Acquisition::Dou).to receive(:collect).and_return(:dou_result)
    allow(Acquisition::Djinni).to receive(:collect).and_return(:djinni_result)
    allow(Acquisition::RemoteOk).to receive(:collect).and_return(:remoteok_result)

    expect(described_class.new.perform("dou")).to eq(:dou_result)
    expect(described_class.new.perform("djinni")).to eq(:djinni_result)
    expect(described_class.new.perform("remoteok")).to eq(:remoteok_result)
    expect(Acquisition::Dou).to have_received(:collect).once
    expect(Acquisition::Djinni).to have_received(:collect).once
    expect(Acquisition::RemoteOk).to have_received(:collect).once
  end

  it "runs search-bound sources once per configured profile query" do
    allow(Acquisition::WorkUa).to receive(:collect).and_return(:work_ua_result)
    allow(Acquisition::RobotaUa).to receive(:collect).and_return(:robota_result)

    expect(described_class.new.perform("work_ua")).to eq([ :work_ua_result ])
    expect(described_class.new.perform("robota_ua")).to eq([ :robota_result ])
    expect(Acquisition::WorkUa).to have_received(:collect).with(search: "Ruby").once
    expect(Acquisition::RobotaUa).to have_received(:collect).with(search: "Ruby").once
  end

  it "fails explicitly for an unsupported source" do
    expect { described_class.new.perform("missing") }
      .to raise_error(ArgumentError, /unsupported acquisition source/)
  end

  it "schedules all Phase 0 local sources plus Remote OK in production" do
    production = YAML.safe_load_file(
      Rails.root.join("config/recurring.yml"),
      aliases: true
    ).fetch("production")

    %w[dou djinni work_ua robota_ua].each do |source_key|
      expect(production.fetch("acquisition_#{source_key}")).to eq(
        "class" => "AcquisitionCollectionJob",
        "queue" => "acquisition",
        "args" => [ source_key ],
        "schedule" => "every 10 minutes"
      )
    end

    expect(production.fetch("acquisition_remoteok")).to eq(
      "class" => "AcquisitionCollectionJob",
      "queue" => "acquisition",
      "args" => [ "remoteok" ],
      "schedule" => "every 15 minutes"
    )
  end
end
