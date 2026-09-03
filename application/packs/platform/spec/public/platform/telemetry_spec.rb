# frozen_string_literal: true

require "rails_helper"

RSpec.describe Platform::Telemetry do
  it "delegates spans to the global OpenTelemetry API without requiring an SDK" do
    provider = double("tracer_provider")
    tracer = double("tracer")

    allow(OpenTelemetry).to receive(:tracer_provider).and_return(provider)
    expect(provider).to receive(:tracer).with("lmx", "1").and_return(tracer)
    expect(tracer).to receive(:in_span).with(
      "example",
      attributes: { "answer" => 42, "enabled" => false },
      record_exception: false
    ).and_yield(:span)

    result = described_class.in_span(
      "example",
      attributes: { answer: 42, enabled: false, omitted: nil },
      record_exception: false
    ) { |span| [ :ok, span ] }

    expect(result).to eq([ :ok, :span ])
  end

  it "adds only non-nil attributes" do
    span = double("span")

    expect(span).to receive(:add_attributes).with({ "count" => 0, "healthy" => false })

    expect(described_class.add_attributes(span, count: 0, healthy: false, missing: nil)).to be(span)
  end
end
