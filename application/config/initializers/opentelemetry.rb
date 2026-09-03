# frozen_string_literal: true

sdk_disabled = ENV["OTEL_SDK_DISABLED"].to_s.casecmp("true").zero?
export_requested = [
  ENV["OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"],
  ENV["OTEL_EXPORTER_OTLP_ENDPOINT"],
  ENV["OTEL_TRACES_EXPORTER"]
].any? { _1.to_s.strip != "" }

if export_requested && !sdk_disabled
  require "opentelemetry/sdk"
  require "opentelemetry/exporter/otlp"

  OpenTelemetry::SDK.configure do |config|
    config.service_name = ENV.fetch("OTEL_SERVICE_NAME", "lmx")
  end
end
