# Observability

LMX uses OpenTelemetry for traces and metrics. Structured application logs remain complementary operational evidence.

Event sourcing, source health and telemetry serve different purposes:

- Event Store: durable business truth.
- SourceRun and SourceHealth: durable acquisition operational history.
- OpenTelemetry: runtime behavior, latency, failures and cross-boundary correlation.

## Traces

A source ingestion trace may contain spans such as:

```text
fetch
parse
persist_observation
reconcile
append_event
notify
```

MCP and API calls should participate in the same distributed trace and propagate correlation identifiers where practical.

## Phase 0 trace contract

Phase 0 uses a stable application-level trace contract rather than relying only on generic Rails or HTTP auto-instrumentation.

Each collector execution starts a root span:

```text
lmx.acquisition.collect
```

with child or downstream spans where the work exists:

```text
lmx.acquisition.fetch
lmx.acquisition.parse
lmx.acquisition.persist_observation
lmx.market_catalog.reconcile
lmx.platform.append_event
lmx.delivery.notify
```

The collection span exposes bounded operational attributes such as:

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

Fetch spans may include the HTTP method, host, response status and transport. Parse spans carry parser version and discovered count. Persistence spans carry observed count. Reconciliation spans may reference opaque posting/opening identifiers and lifecycle states. Event append spans may reference aggregate/event identity. Delivery spans may carry the durable correlation identifier copied from the owning DomainEvent.

Failures mark the active span as failed and record the exception while the durable `SourceRun` remains the authoritative acquisition history. A successful zero-result run is not an error and must remain distinguishable from a parser failure.

Raw payload bodies, vacancy descriptions, credentials, authorization headers and personal search strings must not be copied into telemetry. High-cardinality identifiers may be used on traces when needed for debugging, but must not become metric dimensions.

Instrumentation is fail-open. OpenTelemetry SDK/exporter failure must not change collector, persistence, reconciliation, Outbox or notification semantics. If tracing cannot start, application code continues under a no-op span. Metric recording errors are suppressed after best-effort OpenTelemetry logging.

## Metrics

Phase 0 publishes these application metrics:

```text
lmx.acquisition.duration
lmx.source.fetch.total
lmx.parser.failure.total
lmx.source.observation.created.total
lmx.event.appended.total
lmx.notification.delivery.total
```

`lmx.acquisition.duration` is a histogram in seconds. Counters use low-cardinality dimensions such as source, transport, event/aggregate type, notification kind and bounded outcome values. Correlation IDs, posting IDs, opening IDs, URLs, search strings and other unbounded values are intentionally excluded from metric attributes.

Useful outcome values include:

- source fetch: `success`, `failure`
- acquisition: `success`, `failure`
- Telegram delivery: `sent`, `suppressed`, `failure`

The instrumentation facade depends on the OpenTelemetry APIs. Trace SDK/export and metrics SDK/export are application configuration. OTLP metrics use the dedicated Ruby metrics SDK/exporter while trace export keeps the existing OTLP exporter. When no SDK/exporter is configured, API instrumentation remains a no-op.

## Durable source health

`Acquisition::SourceHealth` is the operational read model for source freshness and reliability. It derives from durable `SourceRun` history rather than transient telemetry and exposes, per source:

- latest run status and ID
- last attempted and last successful timestamps
- transport and collector/adapter/parser versions
- duration
- fetched, discovered and observed counts
- consecutive failures
- latest failure details

This separation matters. Telemetry may be sampled, unavailable or short-lived, while SourceRun history must remain sufficient to answer whether a source ran successfully and when it last produced trustworthy acquisition evidence.

Operational dashboards should combine both layers: use SourceHealth for durable freshness/readiness and OpenTelemetry for latency, failure rates and runtime diagnosis. A broken parser must be visible quickly rather than silently looking like an empty market.

## Correlation across Outbox delivery

When a DomainEvent is created inside an active trace and no explicit correlation ID was supplied, LMX persists the current trace ID as the event correlation ID. Outbox claim snapshots carry that correlation ID into the delivery worker, where it is attached to the notification span as diagnostic context.

This is durable correlation, not synthetic parent-child reconstruction across process boundaries. Explicit business or command correlation IDs continue to take precedence over the trace-derived fallback.

## Retention

Business events and SourceRun evidence are long-lived according to their domain retention policy. High-volume telemetry can use shorter retention appropriate to operational needs.
