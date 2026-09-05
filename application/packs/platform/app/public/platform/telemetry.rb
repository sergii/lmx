# frozen_string_literal: true

require "opentelemetry-api"
require "opentelemetry-metrics-api"

module Platform
  module Telemetry
    INSTRUMENTATION_NAME = "lmx"
    INSTRUMENTATION_VERSION = "1"

    class << self
      def in_span(name, attributes: {}, record_exception: true, &block)
        tracer.in_span(
          name,
          attributes: compact_attributes(attributes),
          record_exception:,
          &block
        )
      end

      def add_attributes(span, attributes)
        attributes = compact_attributes(attributes)
        span.add_attributes(attributes) unless attributes.empty?
        span
      end

      def increment(name, by: 1, attributes: {}, unit: "1", description: nil)
        meter
          .create_counter(name, unit:, description:)
          .add(by, attributes: compact_attributes(attributes))
      end

      def record(name, value, attributes: {}, unit: nil, description: nil)
        meter
          .create_histogram(name, unit:, description:)
          .record(value, attributes: compact_attributes(attributes))
      end

      def current_trace_id
        context = OpenTelemetry::Trace.current_span.context
        context.hex_trace_id if context.valid?
      end

      private

      def tracer
        OpenTelemetry.tracer_provider.tracer(INSTRUMENTATION_NAME, INSTRUMENTATION_VERSION)
      end

      def meter
        OpenTelemetry.meter_provider.meter(INSTRUMENTATION_NAME, version: INSTRUMENTATION_VERSION)
      end

      def compact_attributes(attributes)
        attributes.each_with_object({}) do |(key, value), result|
          result[key.to_s] = value unless value.nil?
        end
      end
    end
  end
end
