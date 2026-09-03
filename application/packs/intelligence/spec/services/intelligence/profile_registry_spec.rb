# frozen_string_literal: true

require "rails_helper"

RSpec.describe Intelligence::ProfileRegistry, type: :model do
  it "exposes the configured personal ranking policy" do
    expect(described_class.source_priority("dou")).to eq(
      "lane" => "local_fast",
      "weight" => 100
    )
    expect(described_class.policies).to include(
      "compensation_hard_reject" => false,
      "geography_hard_reject" => false,
      "infer_job_coexistence" => false,
      "preserve_unknowns" => true
    )
  end

  it "fails explicitly for an unknown source priority" do
    expect { described_class.source_priority("missing") }
      .to raise_error(KeyError, /Unknown source priority/)
  end
end
