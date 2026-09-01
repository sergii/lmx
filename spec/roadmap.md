# Roadmap

## Phase 0 - Start collecting history

Goal: begin accumulating durable observations before the full UI exists.

- establish Rails/PostgreSQL application skeleton
- define Event Store envelope and aggregate versioning
- implement Transactional Inbox and Outbox
- implement source registry loader and schema validation
- build initial source adapters from the highest priority source tier
- persist raw payload metadata and snapshots
- create JobOpening versus JobPosting resolver
- emit discovery/change/lifecycle events
- add basic OpenTelemetry

## Phase 1 - Daily usable product

- canonical opening list
- fit assessment and Action Priority
- Telegram notifications
- manual URL submission
- manual no-URL entry
- personal application state
- Kanban
- list representation
- opening detail with source history

The product should already be useful every day at this phase.

## Phase 2 - Broader discovery

- expand source adapters according to `config/sources.yml`
- API submission
- webhook ingestion
- robust browser-crawl fallback
- richer geographic and compensation extraction
- source health dashboard

## Phase 3 - Market intelligence

After enough history exists:

- vacancy lifetime analytics
- repost/reopen analysis
- company hiring velocity
- cross-source publication timelines
- compensation trends
- demand by technology, seniority, industry, and geography
- source effectiveness analytics

## Phase 4 - Agent-native operation

- production MCP server
- scoped credentials and tool permissions
- agent provenance views
- commands from multiple AI clients
- agent-assisted enrichment and ambiguous deduplication
- audit UI based on domain events

## Phase 5 - Scale only when justified

- search engine if PostgreSQL search is insufficient
- ClickHouse if analytical/event volume requires it
- dedicated stream infrastructure only if throughput or consumer independence requires it

Avoid premature infrastructure complexity while preserving boundaries that allow later extraction.
