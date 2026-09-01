# LMX internal specification

This directory is the working specification for LMX.

LMX is designed as an event-driven market intelligence and personal opportunity tracking system. It combines continuous source ingestion, canonical entity resolution, historical analysis, real-time notifications, and a personal application workflow.

The source registry is machine-readable and lives in `config/sources.yml`. Source names and crawl configuration should not be duplicated in Markdown.

## Core product areas

- Market intelligence: hiring activity, vacancy lifetime, reopen/repost behavior, compensation trends, source distribution, skills, sectors, and geography.
- Opportunity intelligence: ranking and factual normalization of opportunities for the current user.
- Personal workflow: Kanban, list views, application stages, interactions, contacts, reminders, and history.
- Real-time delivery: Telegram as the primary push surface for fresh or materially changed opportunities.
- Agent-native access: MCP and API access for trusted humans, services, crawlers, parsers, and AI agents.

## Architectural principles

1. A real hiring need is not the same thing as a posting on a website.
2. A posting is not the same thing as the way LMX discovered it.
3. Preserve raw observations and provenance before normalization.
4. Domain state is changed through commands, not by direct database mutation from external actors.
5. Accepted domain changes produce immutable domain events.
6. Event Store records business truth. OpenTelemetry records system behavior.
7. Every meaningful change is attributable to an actor, executor, source, and causal chain.
8. Geography, compensation, employment type, and schedule are facts or explicitly labeled interpretations, not automatic rejection rules.
9. Analytics should become more valuable as history accumulates. Start collecting history immediately.
10. LLMs assist with ambiguous interpretation. Deterministic facts and metrics remain deterministic.

See the other files in this directory for the domain model, architecture, analytics, interfaces, event model, and roadmap.
