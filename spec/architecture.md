# Architecture

## High-level flow

```text
External sources
      |
      v
Acquisition adapters
(RSS / HTTP API / HTML / browser)
      |
      v
RawPayload + IngestionRecord
      |
      v
SourceObservation
      |
      v
Normalize / extract
      |
      v
Identity resolution + reconciliation
      |
      +--------------------+
      |                    |
      | no change          v
      |                 Command
      |                    |
      |                    v
      |              Domain model
      |                    |
      |                    v
      |               Event Store
      |                    |
      |          +---------+---------+
      |          |                   |
      |          v                   v
      |      Projections       Transactional Outbox
      |          |                   |
      |          v                   v
      |   Web / analytics      Telegram / search /
      |                       integration events
      |
      +--> evidence remains queryable

Ingress interfaces (Web UI / manual / API / webhook / MCP / import)
      |
      v
Transactional Inbox -> Commands/queries -> same application/domain layer

Entire pipeline -> OpenTelemetry
```

## Acquisition versus ingress

These are separate concepts.

Acquisition transports retrieve external source evidence:

- RSS
- HTTP API
- HTTP/HTML retrieval
- browser automation

Ingress interfaces let humans, systems and agents submit/query LMX:

- manual web input
- HTTP API
- webhook
- MCP
- import

The canonical external source registry lives in `config/sources.yml`. Personal source weighting and ranking policy live under `config/profiles/`.

HTTP/API acquisition should be preferred over browser automation when both are reliable. Browser automation is more expensive and operationally fragile and should be a deliberate fallback.

## Observation boundary

A crawler/parser reports evidence; it does not directly own canonical market state.

`SourceObservation` is the stable boundary between acquisition and Market Catalog. Reconciliation decides whether evidence implies a domain command. See `observations.md`.

## Transactional Inbox

External commands can be retried. The Inbox provides idempotency and processing state.

Minimum metadata:

- message_id
- idempotency_key
- received_at
- interface/client
- principal/credential
- actor
- payload hash/reference
- processing status
- attempt count

Duplicate delivery of the same command must return or reconstruct the prior result rather than apply the mutation twice.

Acquisition fetch retries may have their own idempotency keys and observation identity while still converging on the same evidence pipeline.

## Domain command pipeline

No external actor writes canonical domain tables directly.

```text
Web UI / API / MCP / reconciliation
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

The Event Store is the durable source of business history for domain transitions where history, causality, replay and audit create product value. Projections may be rebuilt from events where practical.

A typical event envelope includes:

- event_id
- event_type
- event_version
- aggregate_type
- aggregate_id
- aggregate_version
- occurred_at
- effective_at when needed
- principal
- credential_id/reference
- actor
- executor
- client/interface
- source/evidence references
- correlation_id
- causation_id
- command_id
- idempotency_key
- data

## Transactional Outbox

State-changing transactions append domain events and outbox records atomically. Asynchronous publishers distribute integration messages to Telegram, search, analytics, websockets, or external consumers.

Internal domain events are not public API contracts. Integration events are versioned and shaped separately.

## Raw data retention

Raw payloads should be retained when legally and operationally appropriate. A pragmatic initial design is PostgreSQL metadata plus object storage for larger raw payloads.

## Bounded contexts

The initial modular boundaries are:

- Acquisition
- Market Catalog
- Intelligence
- Personal CRM
- Delivery
- Integration

See `bounded-contexts.md` for ownership and cross-context rules.

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

Prefer deterministic processing for timestamps, source identities, hashes, salary arithmetic, vacancy lifetime, source counts, reopen counts, FX conversion metadata, and statistical aggregates.

Use LLMs for ambiguity: title normalization, free-text skill extraction, industry classification, semantic same-opening checks, geographic interpretation, and fit explanations.

LLM-assisted identity decisions remain versioned, explainable and reversible.
