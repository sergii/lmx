# Architecture

## Architectural shape

LMX is a domain-driven modular monolith.

The initial system should remain one Rails application and one PostgreSQL operational database, with explicit bounded contexts and package boundaries rather than early service decomposition.

Target context/package boundaries include:

- Workspace / Identity foundation
- Acquisition
- Market Catalog
- Talent Profile
- Intelligence
- Personal CRM
- optional Recruiting
- Delivery
- Integration

Packwerk (or an equivalent package-boundary checker if Packwerk proves incompatible with the chosen Rails/Ruby baseline) should enforce declared dependencies and privacy boundaries in CI.

The modular monolith gives LMX one transactional boundary and simple operations while preserving the option to extract a package later if scale, team ownership, or independent deployment justifies it.

## LMX is the system of record

External agents are replaceable processors, not the semantic authority for LMX.

OpenBot, GrokBot, P, Hermes, ChatGPT/Codex-driven workers, or future agents may perform:

- discovery
- page retrieval
- extraction
- enrichment
- preliminary qualification
- semantic classification
- ambiguous identity suggestions
- candidate/opening pre-analysis

But LMX owns:

- the canonical ontology
- source/evidence provenance
- raw-payload references and observation history
- canonical Company / JobOpening / JobPosting / Candidate identities
- domain rules and lifecycle semantics
- versioned MatchAssessments
- personal application/interview state
- accepted domain events
- auditability and replay semantics

An agent result is stored as evidence or versioned derived analysis with processor/model/rules provenance. It does not directly overwrite canonical state.

This allows agents to be changed, compared, rerun, or removed without changing the meaning of the LMX data model.

## High-level flow

```text
External sources
      |
      +-----------------------------+
      |                             |
      v                             v
Native acquisition adapters     External agent workers
(RSS / HTTP API / HTML /        (OpenBot / GrokBot /
 browser)                        P / Hermes / others)
      |                             |
      +--------------+--------------+
                     |
                     v
          RawPayload + IngestionRecord
                     |
                     v
              SourceObservation
                     |
          +----------+-----------+
          |                      |
          v                      v
 deterministic extract      agent pre-analysis /
 / normalization            enrichment
          |                      |
          +----------+-----------+
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
- external agent-assisted acquisition/enrichment

Ingress interfaces let humans, systems and agents submit/query LMX:

- manual web input
- HTTP API
- webhook
- MCP
- import

The canonical external source registry lives in `config/sources.yml`. Personal source weighting and ranking policy live under `config/profiles/`.

HTTP/API acquisition should be preferred over browser automation when both are reliable. Browser automation is more expensive and operationally fragile and should be a deliberate fallback.

External agent workers should be used where they add leverage, not because they are the only place where domain knowledge lives.

## Observation boundary

A crawler/parser/agent reports evidence; it does not directly own canonical market state.

`SourceObservation` is the stable boundary between acquisition and Market Catalog. Reconciliation decides whether evidence implies a domain command. See `observations.md`.

Agent-returned preliminary analysis should retain at least:

- processor/agent identity
- model/version when applicable
- rules/prompt/profile version when applicable
- input observation/evidence references
- generated_at
- confidence when meaningful
- structured result

Reprocessing the same evidence with a newer processor must create a new analysis version rather than silently mutate history.

## Workspace execution boundary

Tenant execution must be explicit outside ordinary request handling.

Prefer an API such as:

```ruby
WorkspaceContext.with(workspace) do
  # domain/application work
end
```

for background jobs, collectors, replay, projections, MCP commands, scripts, and administrative workflows.

PostgreSQL RLS can remain the database-enforced security boundary, but application correctness should not depend on a pervasive implicit `default_scope`.

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
Web UI / API / MCP / reconciliation / agent-result acceptance
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
- workspace_id where applicable
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

## Agent and MCP boundary

LMX exposes MCP as a first-class controlled interface to its application command/query layer.

Examples of MCP clients include ChatGPT, Codex, Grok-based agents, Claude clients, OpenBot-style agents, and custom internal workers.

Agents can use MCP to:

- query openings, candidates, companies, matches, applications, interviews, and market intelligence
- submit evidence/observations
- request or store versioned pre-analysis
- create/advance application workflows when authorized
- request interview preparation
- annotate or propose identity-resolution decisions

MCP tools never imply direct ActiveRecord/database access.

LMX may also invoke external processors through explicit adapters. When an external processor exposes an MCP server, LMX can act as an MCP client; otherwise HTTP, queue, or another explicit adapter is acceptable. The domain boundary remains the same either way.

See `interfaces.md`.

## Raw data retention

Raw payloads should be retained when legally and operationally appropriate. A pragmatic initial design is PostgreSQL metadata plus object storage for larger raw payloads.

## Bounded contexts and package enforcement

See `bounded-contexts.md` for ownership and cross-context rules.

Within the Rails monolith, packages should expose narrow public application APIs and keep internal models/services private where practical.

A likely physical layout is:

```text
application/
  packs/
    workspace/
    acquisition/
    market_catalog/
    talent_profile/
    intelligence/
    personal_crm/
    recruiting/
    delivery/
    integration/
```

Exact file layout can evolve, but dependency direction should be checked automatically in CI.

Shared code must stay intentionally small. Do not create a generic `shared` package that becomes an escape hatch around boundaries.

## Application stack

Initial implementation target:

- Rails 8.x
- PostgreSQL
- background jobs through a Rails-compatible queue
- Inertia/React for the web UI
- Telegram Bot API
- OpenTelemetry
- Packwerk or equivalent package-boundary enforcement

PostgreSQL is sufficient for initial analytics. ClickHouse can be introduced later if event/snapshot volume or analytical workloads justify it.

## Deterministic versus LLM/agent work

Prefer deterministic processing for timestamps, source identities, hashes, salary arithmetic, vacancy lifetime, source counts, reopen counts, FX conversion metadata, and statistical aggregates.

Use LLMs/agents for ambiguity and leverage: title normalization, free-text skill extraction, industry classification, semantic same-opening checks, geographic interpretation, candidate/opening match explanations, company/interview enrichment, and interview preparation.

LLM/agent-assisted identity and assessment decisions remain versioned, explainable, evidence-backed, and reversible where the underlying decision can be reversed.