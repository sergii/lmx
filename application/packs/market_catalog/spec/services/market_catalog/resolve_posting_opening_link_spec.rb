# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarketCatalog::ResolvePostingOpeningLink, type: :model do
  let(:observed_at) { Time.zone.parse("2026-09-02 00:30:00") }
  let(:posting) do
    MarketCatalog::RecordPosting.call(
      source_key: "dou",
      external_id: "vacancies/123",
      canonical_url: "https://jobs.dou.ua/companies/example/vacancies/123/",
      title: "Senior Ruby Engineer",
      observed_at:
    )
  end
  let(:first_opening) do
    MarketCatalog::CreateOpening.call(
      canonical_title: "Senior Ruby Engineer",
      first_seen_at: observed_at
    )
  end
  let(:second_opening) do
    MarketCatalog::CreateOpening.call(
      canonical_title: "Senior Backend Engineer",
      first_seen_at: observed_at
    )
  end

  it "records immutable evidence when linking a posting to an opening" do
    decision = described_class.call(
      posting_id: posting.typed_id,
      opening_id: first_opening.typed_id,
      confidence: 0.98,
      evidence: [ { "kind" => "canonical_application_url", "value" => "https://example.test/apply/123" } ],
      resolver_key: "deterministic",
      resolver_version: "v1",
      decided_at: observed_at
    )

    expect(posting.reload.job_opening).to eq(first_opening)
    expect(decision).to have_attributes(
      decision_type: "link_posting",
      from_job_opening: nil,
      to_job_opening: first_opening,
      resolver_key: "deterministic",
      resolver_version: "v1"
    )
    expect(decision.typed_id).to start_with("resolution_decision_")
    expect(decision).to be_readonly
    expect { decision.update!(confidence: 0.5) }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "creates another decision for a relink instead of rewriting history" do
    first_decision = described_class.call(
      posting_id: posting.id,
      opening_id: first_opening.id,
      confidence: 0.8,
      evidence: [ { "kind" => "source_external_id" } ],
      resolver_key: "resolver",
      resolver_version: "v1"
    )

    second_decision = described_class.call(
      posting_id: posting.id,
      opening_id: second_opening.id,
      confidence: 0.95,
      evidence: [ { "kind" => "manual_review" } ],
      resolver_key: "resolver",
      resolver_version: "v2"
    )

    expect(first_decision.reload).to have_attributes(
      decision_type: "link_posting",
      to_job_opening: first_opening
    )
    expect(second_decision).to have_attributes(
      decision_type: "relink_posting",
      from_job_opening: first_opening,
      to_job_opening: second_opening
    )
    expect(posting.reload.job_opening).to eq(second_opening)
    expect(MarketCatalog::ResolutionDecision.count).to eq(2)
  end

  it "records unlinking as a new reversible decision" do
    described_class.call(
      posting_id: posting.id,
      opening_id: first_opening.id,
      confidence: 0.9,
      evidence: [ { "kind" => "source_external_id" } ],
      resolver_key: "resolver",
      resolver_version: "v1"
    )

    decision = described_class.call(
      posting_id: posting.id,
      opening_id: nil,
      confidence: 1.0,
      evidence: [ { "kind" => "manual_correction" } ],
      resolver_key: "human_review",
      resolver_version: "v1"
    )

    expect(decision).to have_attributes(
      decision_type: "unlink_posting",
      from_job_opening: first_opening,
      to_job_opening: nil
    )
    expect(posting.reload.job_opening).to be_nil
  end

  it "is a no-op when the requested link is already current" do
    described_class.call(
      posting_id: posting.id,
      opening_id: first_opening.id,
      confidence: 0.9,
      evidence: [ { "kind" => "source_external_id" } ],
      resolver_key: "resolver",
      resolver_version: "v1"
    )

    expect do
      result = described_class.call(
        posting_id: posting.id,
        opening_id: first_opening.id,
        confidence: 0.9,
        evidence: [ { "kind" => "source_external_id" } ],
        resolver_key: "resolver",
        resolver_version: "v1"
      )
      expect(result).to be_nil
    end.not_to change(MarketCatalog::ResolutionDecision, :count)
  end
end
