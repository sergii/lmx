# Observability

LMX uses OpenTelemetry for traces, metrics, and structured logs.

Event sourcing and telemetry serve different purposes:

- Event Store: durable business truth.
- OpenTelemetry: runtime and operational behavior.

## Traces

A source ingestion trace may contain spans such as:

```text
fetch
parse
normalize
resolve_company
resolve_opening
deduplicate
append_events
update_projection
score
notify
```

MCP and API calls should participate in the same distributed trace and propagate correlation identifiers where practical.

## Phase 0 acquisition trace contract

Phase 0 uses a stable application-level trace contract rather than relying only on generic Rails or HTTP auto-instrumentation.

Each collector execution starts a root span:

```text
lmx.acquisition.collect
```

with child spans where the work exists:

```text
lmx.acquisition.fetch
lmx.acquisition.parse
lmx.acquisition.observe
```

The collection span should expose low-cardinality operational attributes such as:

- `lmx.source.id`
- `lmx.source.transport`
- `lmx.source.strategy`
- `lmx.source.run_id` once the durable SourceRun exists
- `lmx.source.search_present` as a boolean rather than the raw search string
- `lmx.source.collector_version`
- `lmx.source.adapter_version`
- `lmx.source.parser_version`
- `lmx.source.status`
- `lmx.source.fetched_count`
- `lmx.source.discovered_count`
- `lmx.source.observed_count`

Fetch spans may include the HTTP method, host, response status and transport. Parse spans should carry parser version and discovered count. Observe spans should carry observed count.

Failures must mark the active span as failed and record the exception while the durable `SourceRun` remains the authoritative operational history. A successful zero-result run is not an error.

Raw payload bodies, vacancy descriptions, credentials, authorization headers, personal search strings and other high-cardinality or sensitive content must not be copied into span attributes or events. Telemetry may reference durable IDs and bounded metadata instead.

OTLP export is application configuration. Collector/domain code depends only on the OpenTelemetry API and remains vendor-neutral. When the SDK/exporter is disabled or not configured, instrumentation must degrade to a no-op without changing collector behavior.

## Metrics

Candidate metrics:

```text
lmx_ingestion_duration_seconds
lmx_source_fetch_total
lmx_postings_discovered_total
lmx_dedup_matches_total
lmx_parser_failures_total
lmx_events_appended_total
lmx_inbox_duplicates_total
lmx_outbox_pending
lmx_mcp_requests_total
lmx_mcp_request_duration_seconds
lmx_notifications_sent_total
lmx_notification_failures_total
```

## Source health

Operational dashboards should show per-source freshness and reliability, including last successful observation, error rate, parser failures, ingestion latency, and newly discovered postings.

A broken parser should be visible quickly rather than silently producing an empty market.

## Retention

Business events are long-lived. High-volume telemetry can use shorter retention appropriate to operational needs.
