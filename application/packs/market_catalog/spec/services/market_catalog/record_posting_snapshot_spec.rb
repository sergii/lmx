# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarketCatalog::RecordPostingSnapshot, type: :model do
  let(:observed_at) { Time.zone.parse("2026-09-02 10:00:00") }
  let(:posting) do
    MarketCatalog::RecordPosting.call(
      source_key: "dou",
      external_id: "vacancies/123",
      canonical_url: "https://jobs.dou.ua/companies/example/vacancies/123/",
      title: "Senior Ruby Engineer",
      observed_at:
    )
  end
  let(:source_observation_id) { TypeID.from_uuid("source_observation", SecureRandom.uuid).to_s }
  let(:attributes) do
    {
      posting_id: posting.typed_id,
      source_observation_id:,
      observed_at:,
      presence_state: "present",
      normalizer_key: "dou_job_posting",
      normalizer_version: "v1",
      title: "Senior Ruby Engineer",
      description_fingerprint: "a" * 64,
      facts: {
        "location" => { "value" => "Remote", "evidence_level" => "LISTED" },
        "employment_type" => { "value" => "full_time", "evidence_level" => "INFERRED" }
      },
      metadata: { "parser_version" => "2026-09-02" }
    }
  end

  it "records an immutable normalized view tied to one source observation" do
    snapshot = described_class.call(**attributes)

    expect(snapshot).to have_attributes(
      job_posting: posting,
      presence_state: "present",
      title: "Senior Ruby Engineer",
      normalizer_key: "dou_job_posting",
      normalizer_version: "v1"
    )
    expect(snapshot.typed_id).to start_with("posting_snapshot_")
    expect(snapshot.content_digest).to match(/\A[0-9a-f]{64}\z/)
    expect(snapshot).to be_readonly
    expect { snapshot.update!(title: "Changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "is idempotent for the same observation and normalized content" do
    first_snapshot = described_class.call(**attributes)

    expect do
      second_snapshot = described_class.call(
        **attributes.merge(
          facts: {
            "employment_type" => { "evidence_level" => "INFERRED", "value" => "full_time" },
            "location" => { "evidence_level" => "LISTED", "value" => "Remote" }
          }
        )
      )
      expect(second_snapshot).to eq(first_snapshot)
    end.not_to change(MarketCatalog::PostingSnapshot, :count)
  end

  it "rejects conflicting normalized output for the same source observation" do
    described_class.call(**attributes)

    expect do
      described_class.call(**attributes.merge(title: "Different title"))
    end.to raise_error(
      MarketCatalog::RecordPostingSnapshot::ObservationConflict,
      "source observation already produced a different posting snapshot"
    )
  end

  it "preserves explicit closure evidence without directly closing canonical posting state" do
    snapshot = described_class.call(
      **attributes.merge(
        presence_state: "explicit_closed",
        facts: { "closure_text" => { "value" => "Vacancy closed", "evidence_level" => "LISTED" } }
      )
    )

    expect(snapshot.presence_state).to eq("explicit_closed")
    expect(posting.reload.lifecycle_state).to eq("present")
  end
end
