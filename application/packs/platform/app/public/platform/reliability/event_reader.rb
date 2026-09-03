# frozen_string_literal: true

module Platform
  module Reliability
    class EventReader
      class << self
        def fetch(aggregate_type:, aggregate_id:)
          events = Platform::DomainEvent
            .where(aggregate_type:, aggregate_id:)
            .order(:aggregate_version, :id)

          deep_freeze(events.map { event_snapshot(_1) })
        end

        private

        def event_snapshot(event)
          {
            id: TypeID.from_uuid("event", event.id).to_s,
            workspace_id: TypeID.from_uuid("org", event.organization_id).to_s,
            event_type: event.event_type,
            event_version: event.event_version,
            aggregate_type: event.aggregate_type,
            aggregate_id: event.aggregate_id,
            aggregate_version: event.aggregate_version,
            occurred_at: event.occurred_at,
            effective_at: event.effective_at,
            command_id: event.command_id,
            correlation_id: event.correlation_id,
            causation_id: event.causation_id,
            data: event.data.deep_dup
          }
        end

        def deep_freeze(value)
          case value
          when Hash
            value.each { |key, nested| key.freeze; deep_freeze(nested) }
          when Array
            value.each { deep_freeze(_1) }
          end
          value.freeze
        end
      end
    end
  end
end
