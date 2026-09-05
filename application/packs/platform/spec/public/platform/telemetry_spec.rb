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

  it "falls back to a no-op span when tracing cannot start" do
    allow(OpenTelemetry).to receive(:tracer_provider).and_raise(StandardError, "telemetry unavailable")
    allow(OpenTelemetry.logger).to receive(:warn)

    result = described_class.in_span("example") do |span|
      span.add_attributes("safe" => true)
      :application_result
    end

    expect(result).to eq(:application_result)
  end

  it "does not swallow application failures raised inside an active span" do
    provider = double("tracer_provider")
    tracer = double("tracer")
    allow(OpenTelemetry).to receive(:tracer_provider).and_return(provider)
    allow(provider).to receive(:tracer).and_return(tracer)
    allow(tracer).to receive(:in_span).and_yield(:span)

    expect do
      described_class.in_span("example") { raise ArgumentError, "application failure" }
    end.to raise_error(ArgumentError, "application failure")
  end

  it "adds only non-nil attributes" do
    span = double("span")

    expect(span).to receive(:add_attributes).with({ "count" => 0, "healthy" => false })

    expect(described_class.add_attributes(span, count: 0, healthy: false, missing: nil)).to be(span)
  end

  it "records counters through the global OpenTelemetry meter provider" do
    provider = double("meter_provider")
    meter = double("meter")
    counter = double("counter")

    allow(OpenTelemetry).to receive(:meter_provider).and_return(provider)
    expect(provider).to receive(:meter).with("lmx", version: "1").and_return(meter)
    expect(meter).to receive(:create_counter).with(
      "lmx.example.total",
      unit: "1",
      description: "Example counter"
    ).and_return(counter)
    expect(counter).to receive(:add).with(2, attributes: { "outcome" => "success" })

    described_class.increment(
      "lmx.example.total",
      by: 2,
      description: "Example counter",
      attributes: { outcome: "success", omitted: nil }
    )
  end

  it "fails open when metric recording is unavailable" do
    allow(OpenTelemetry).to receive(:meter_provider).and_raise(StandardError, "metrics unavailable")
    allow(OpenTelemetry.logger).to receive(:warn)

    expect(described_class.increment("lmx.example.total")).to be_nil
    expect(described_class.record("lmx.example.duration", 0.25)).to be_nil
  end

  it "records histograms through the global OpenTelemetry meter provider" do
    provider = double("meter_provider")
    meter = double("meter")
    histogram = double("histogram")

    allow(OpenTelemetry).to receive(:meter_provider).and_return(provider)
    expect(provider).to receive(:meter).with("lmx", version: "1").and_return(meter)
    expect(meter).to receive(:create_histogram).with(
      "lmx.example.duration",
      unit: "s",
      description: "Example duration"
    ).and_return(histogram)
    expect(histogram).to receive(:record).with(0.25, attributes: { "outcome" => "success" })

    described_class.record(
      "lmx.example.duration",
      0.25,
      unit: "s",
      description: "Example duration",
      attributes: { outcome: "success" }
    )
  end

  it "exposes the current trace ID only for a valid span context" do
    context = double("span_context", valid?: true, hex_trace_id: "0123456789abcdef")
    span = double("span", context:)
    allow(OpenTelemetry::Trace).to receive(:current_span).and_return(span)

    expect(described_class.current_trace_id).to eq("0123456789abcdef")
  end
end
