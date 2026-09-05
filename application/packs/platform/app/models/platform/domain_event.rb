# frozen_string_literal: true

module Platform
  class DomainEvent < ApplicationRecord
    self.table_name = "platform_domain_events"

    APPEND_SPAN = "lmx.platform.append_event"
    EVENTS_APPENDED_TOTAL = "lmx.event.appended.total"

    validates :organization_id, :event_type, :event_version, :aggregate_type, :aggregate_id,
      :aggregate_version, :occurred_at, presence: true
    validates :event_version, :aggregate_version,
      numericality: { only_integer: true, greater_than: 0 }

    around_create :trace_append
    after_create_commit :record_append_metric

    def readonly?
      persisted?
    end

    before_destroy { throw :abort }

    private

    def trace_append
      Platform::Telemetry.in_span(
        APPEND_SPAN,
        attributes: {
          "lmx.event.type" => event_type,
          "lmx.aggregate.type" => aggregate_type,
          "lmx.aggregate.id" => aggregate_id
        }
      ) do
        self.correlation_id ||= Platform::Telemetry.current_trace_id
        yield
      end
    end

    def record_append_metric
      Platform::Telemetry.increment(
        EVENTS_APPENDED_TOTAL,
        description: "Committed domain events",
        attributes: {
          "lmx.event.type" => event_type,
          "lmx.aggregate.type" => aggregate_type
        }
      )
    end
  end
end
