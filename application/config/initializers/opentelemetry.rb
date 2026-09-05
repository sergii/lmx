# frozen_string_literal: true

sdk_disabled = ENV["OTEL_SDK_DISABLED"].to_s.casecmp("true").zero?
exporter_enabled = ->(value) do
  normalized = value.to_s.strip
  normalized.present? && normalized != "none"
end

shared_otlp_endpoint = ENV["OTEL_EXPORTER_OTLP_ENDPOINT"].to_s.strip.present?
traces_requested = shared_otlp_endpoint ||
  ENV["OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"].to_s.strip.present? ||
  exporter_enabled.call(ENV["OTEL_TRACES_EXPORTER"])
metrics_requested = shared_otlp_endpoint ||
  ENV["OTEL_EXPORTER_OTLP_METRICS_ENDPOINT"].to_s.strip.present? ||
  exporter_enabled.call(ENV["OTEL_METRICS_EXPORTER"])

if (traces_requested || metrics_requested) && !sdk_disabled
  require "opentelemetry/sdk"
  require "opentelemetry/exporter/otlp" if traces_requested

  if metrics_requested
    require "opentelemetry-metrics-sdk"
    require "opentelemetry-exporter-otlp-metrics"
  end

  original_traces_exporter = ENV["OTEL_TRACES_EXPORTER"]
  ENV["OTEL_TRACES_EXPORTER"] = "none" if !traces_requested && original_traces_exporter.blank?

  OpenTelemetry::SDK.configure do |config|
    config.service_name = ENV.fetch("OTEL_SERVICE_NAME", "lmx")
  end
ensure
  if defined?(original_traces_exporter) && original_traces_exporter.nil?
    ENV.delete("OTEL_TRACES_EXPORTER")
  elsif defined?(original_traces_exporter)
    ENV["OTEL_TRACES_EXPORTER"] = original_traces_exporter
  end
end
