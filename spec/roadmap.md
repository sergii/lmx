# Roadmap

## Phase 0 - Capture evidence immediately

Goal: start accumulating durable history before the full application architecture and UI are complete.

Day-one priority:

- get the first highest-priority source observations into durable append-only storage
- persist source timestamps, `observed_at`, raw payload references/hashes, and adapter/parser version
- avoid losing historical evidence while the canonical domain pipeline is still being built

In parallel, establish the durable architecture:

- Rails/PostgreSQL application skeleton
- source registry loader and schema validation
- search/ranking profile loader
- SourceObservation model and observation identity/idempotency
- Event Store envelope and aggregate versioning
- Transactional Inbox and Outbox
- initial Acquisition and Market Catalog boundaries
- JobOpening versus JobPosting resolver
- reversible ResolutionDecision records
- lifecycle reconciliation that distinguishes missing from closed
- basic OpenTelemetry and source-health signals

Temporary collectors are acceptable if they preserve enough raw evidence to reprocess later.

## Phase 1 - Daily usable product

- canonical opening list
- fit assessment, Opportunity Score and Action Priority
- Telegram near-real-time notifications
- manual URL submission
- manual no-URL entry
- personal application attempts/state
- Kanban
- list representation
- opening detail with source/observation history
- first local/fast source adapters operating continuously

The product should already be useful every day at this phase.

## Phase 2 - Broader discovery and resilient acquisition

- expand adapters according to `config/sources.yml`
- API submission
- webhook ingestion
- MCP write/query ingress
- robust browser fallback where justified
- direct company-career adapters/platform families
- richer geographic and compensation extraction
- source health dashboard
- access/robots/terms/rate-limit review as sources become operational

## Phase 3 - Market intelligence

After enough history exists:

- vacancy lifetime analytics with closure confidence
- repost/reopen analysis
- company hiring velocity
- cross-source publication/observation timelines
- compensation trends with historical FX metadata
- demand by technology, seniority, industry and geography
- source effectiveness analytics
- identity-resolution quality/confidence analytics

## Phase 4 - Agent-native operation

- production MCP server
- scoped credentials and tool permissions
- principal/actor/executor/client provenance views
- commands from multiple AI clients
- agent-assisted enrichment and ambiguous identity resolution
- reversible merge/relink tools
- audit UI based on observations, commands and domain events

## Phase 5 - Scale only when justified

- search engine if PostgreSQL search is insufficient
- ClickHouse if analytical/event volume requires it
- dedicated stream infrastructure only if throughput or consumer independence requires it

Avoid premature infrastructure complexity while preserving boundaries that allow later extraction.
