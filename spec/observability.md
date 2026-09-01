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
