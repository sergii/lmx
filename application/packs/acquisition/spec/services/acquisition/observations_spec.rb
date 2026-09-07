# frozen_string_literal: true

require "rails_helper"

RSpec.describe Acquisition::Observations, type: :model do
  it "exposes immutable source observation snapshots through a public boundary" do
    observed_at = Time.zone.parse("2026-09-07 12:00:00")
    source_run = Acquisition::SourceRuns.start(
      source_key: "dou",
      transport: "rss",
      started_at: observed_at - 1.second,
      run_key: "dou:observations-public-api",
      collector_version: Acquisition::Dou::COLLECTOR_VERSION,
      adapter_version: Acquisition::Dou::ADAPTER_VERSIONS.fetch("rss"),
      parser_version: Acquisition::Dou::PARSER_VERSIONS.fetch("rss"),
      provenance: {}
    )
    observation = Acquisition::RecordSourceObservation.call(
      source_run:,
      observed_at:,
      raw_payload: "raw vacancy evidence",
      external_id: "379948",
      canonical_url: "https://jobs.dou.ua/companies/acme/vacancies/379948/",
      payload: {
        "record_type" => "job_posting",
        "source" => "dou",
        "source_record_key" => "379948",
        "url" => "https://jobs.dou.ua/companies/acme/vacancies/379948/",
        "title" => "Senior Ruby Engineer"
      }
    )

    snapshot = described_class.fetch(observation.typed_id)

    expect(snapshot).to include(
      id: observation.typed_id,
      source_key: "dou",
      external_id: "379948",
      presence_state: "present"
    )
    expect(snapshot.fetch(:payload).fetch("title")).to eq("Senior Ruby Engineer")
    expect(snapshot).to be_frozen
    expect(snapshot.fetch(:payload)).to be_frozen
  end

  it "maps missing observations to a stable public error" do
    missing = TypeID.from_uuid("source_observation", SecureRandom.uuid).to_s

    expect { described_class.fetch(missing) }
      .to raise_error(described_class::NotFound, "source observation not found")
  end
end
