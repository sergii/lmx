# frozen_string_literal: true

require "opentelemetry-api"

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

      private

      def tracer
        OpenTelemetry.tracer_provider.tracer(INSTRUMENTATION_NAME, INSTRUMENTATION_VERSION)
      end

      def compact_attributes(attributes)
        attributes.each_with_object({}) do |(key, value), result|
          result[key.to_s] = value unless value.nil?
        end
      end
    end
  end
end
