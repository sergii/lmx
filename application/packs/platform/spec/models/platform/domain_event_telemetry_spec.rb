# frozen_string_literal: true

require "rails_helper"

RSpec.describe Platform::DomainEvent, type: :model do
  let(:connection) { ActiveRecord::Base.connection }
  let(:workspace_uuid) { SecureRandom.uuid }

  around do |example|
    previous = connection.select_value("SELECT current_setting('app.current_organization', true)")
    connection.execute(
      "SELECT set_config('app.current_organization', #{connection.quote(workspace_uuid.to_s)}, false)"
    )
    example.run
  ensure
    if previous.present?
      connection.execute(
        "SELECT set_config('app.current_organization', #{connection.quote(previous)}, false)"
      )
    else
      connection.execute("RESET app.current_organization")
    end
  end

  it "traces committed appends, records a metric, and persists the trace as correlation ID" do
    span = Struct.new(:attributes).new({})
    allow(Platform::Telemetry).to receive(:in_span).and_yield(span)
    allow(Platform::Telemetry).to receive(:current_trace_id).and_return("0123456789abcdef")
    allow(Platform::Telemetry).to receive(:increment)

    result = Platform::Reliability::Api.append_domain_event(
      event_type: "job_posting.updated",
      aggregate_type: "JobPosting",
      aggregate_id: "posting_01test",
      expected_aggregate_version: 0,
      data: { changed: true }
    )

    expect(result.dig(:event, :correlation_id)).to eq("0123456789abcdef")
    expect(Platform::Telemetry).to have_received(:in_span).with(
      "lmx.platform.append_event",
      attributes: {
        "lmx.event.type" => "job_posting.updated",
        "lmx.aggregate.type" => "JobPosting",
        "lmx.aggregate.id" => "posting_01test"
      }
    )
    expect(Platform::Telemetry).to have_received(:increment).with(
      "lmx.event.appended.total",
      description: "Committed domain events",
      attributes: {
        "lmx.event.type" => "job_posting.updated",
        "lmx.aggregate.type" => "JobPosting"
      }
    )
  end
end
