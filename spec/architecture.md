# Architecture

## High-level flow

```text
Sources and humans
       |
       v
Ingestion adapters
       |
       v
Raw observations
       |
       v
Transactional Inbox
       |
       v
Commands
       |
       v
Domain model
       |
       v
Event Store
       |
       +-------------------+
       |                   |
       v                   v
Projections          Transactional Outbox
       |                   |
       v                   v
Web / analytics      Telegram / search / integrations

Entire pipeline -> OpenTelemetry
```

## Ingestion

LMX supports multiple ingress transports behind a common adapter boundary:

- RSS
- HTTP API
- HTTP scrape
- browser crawl
- webhook
- public or private API submission
- manual entry
- bulk import

Transport is not part of the core job identity. All ingestion paths converge on the same normalization, identity resolution, command handling, and event pipeline.

HTTP parsing should be preferred over browser automation when both are reliable. Browser crawling is more expensive and should be a deliberate fallback for JavaScript-heavy or authenticated sources.

The canonical source registry and candidate transports live in `config/sources.yml`.

## Transactional Inbox

External messages and commands can be retried. The inbox provides idempotency and processing state.

Minimum metadata:

- message_id
- idempotency_key
- received_at
- source
- actor
- payload hash/reference
- processing status
- attempt count

Duplicate delivery of the same command must return or reconstruct the prior result rather than applying the mutation twice.

## Domain command pipeline

No external actor writes domain tables directly.

```text
Web UI / API / MCP / crawler / agent
                |
                v
             Command
                |
                v
        Application service
                |
                v
          Domain rules
                |
                v
          Domain events
```

Commands express intent. Events express facts that already happened.

## Event Store

The Event Store is the durable source of business history. Projections may be rebuilt from events where practical.

A typical event envelope includes:

- event_id
- event_type
- event_version
- aggregate_type
- aggregate_id
- aggregate_version
- occurred_at
- actor
- executor
- source
- correlation_id
- causation_id
- command_id
- idempotency_key
- data

## Transactional Outbox

State-changing transactions append domain events and outbox records atomically. Asynchronous publishers then distribute integration messages to Telegram, search, analytics, websockets, or external consumers.

Internal domain events are not public API contracts. Integration events may be versioned and shaped separately.

## Raw data retention

Raw payloads should be retained when legally and operationally appropriate. A pragmatic initial design is PostgreSQL metadata plus object storage for larger raw payloads.

## Application stack

Initial implementation target:

- Rails 8.x
- PostgreSQL
- background jobs through a Rails-compatible queue
- Hotwire or Inertia/React for the web UI
- Telegram Bot API
- OpenTelemetry

PostgreSQL is sufficient for initial analytics. ClickHouse can be introduced later if event/snapshot volume or analytical workloads justify it.

## Deterministic versus LLM work

Prefer deterministic processing for timestamps, source identities, hashes, salary arithmetic, vacancy lifetime, source counts, reopen counts, and statistical aggregates.

Use LLMs for ambiguity: title normalization, free-text skill extraction, industry classification, semantic same-opening checks, geographic interpretation, and fit explanations.
