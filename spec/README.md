# LMX internal specification

This directory is the working specification for LMX.

LMX is designed as an event-driven market intelligence and personal opportunity tracking system. It combines continuous source ingestion, canonical entity resolution, historical analysis, real-time notifications, and a personal application workflow.

The external source registry is machine-readable and lives in `config/sources.yml`. Search/ranking policy lives separately under `config/profiles/`. Source names and crawl configuration should not be duplicated in Markdown.

## Specification map

- `vision.md` - product intent and separation of market state from personal state.
- `product.md` - Telegram, web, Kanban, list, manual entry, ranking.
- `domain.md` - canonical entities and invariants.
- `bounded-contexts.md` - DDD boundaries and ownership.
- `observations.md` - evidence, time semantics, absence/closure semantics.
- `events.md` - commands, domain events, integration events, audit metadata.
- `architecture.md` - end-to-end pipeline, Inbox/Outbox, projections, storage.
- `interfaces.md` - API, MCP, agents, permissions, provenance.
- `analytics.md` - lifecycle, compensation, source and demand intelligence.
- `observability.md` - OpenTelemetry and operational source health.
- `roadmap.md` - implementation order.
- `development/parallel-development.md` - branches, worktrees, package lanes, shared-file and migration rules for concurrent humans and agents.
- `development/ownership.md` - semantic ownership, CODEOWNERS, Backstage and notification-routing model.
- `decisions/` - accepted architectural decisions.

Machine-readable semantic ownership lives in `config/ownership.yml`. GitHub review routing lives in `.github/CODEOWNERS`. Coding-agent repository instructions live in `AGENTS.md`.

## Architectural principles

1. A real hiring need is not the same thing as a posting on a website.
2. A posting is not the same thing as the way LMX discovered it.
3. A source observation is evidence, not automatically a domain mutation.
4. Preserve raw observations and provenance before normalization.
5. Domain state is changed through commands, not direct database mutation by external actors.
6. Accepted domain changes produce immutable domain events.
7. Event Store records business truth. OpenTelemetry records system behavior.
8. Every meaningful change is attributable to principal, actor, executor, client, source, and causal chain where applicable.
9. Geography, compensation, employment type, and schedule are facts or explicitly labeled interpretations, not automatic rejection rules.
10. Identity resolution and merge decisions must be explainable and reversible.
11. Absence from a source is evidence of absence, not automatic proof of closure.
12. Analytics should become more valuable as history accumulates. Start collecting history immediately.
13. LLMs assist with ambiguity. Deterministic facts and metrics remain deterministic.
14. Package boundaries are also parallel-development boundaries: the repository should be understandable and safely changeable by independent human or agent sessions.
