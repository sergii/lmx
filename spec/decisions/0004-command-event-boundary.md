# ADR 0004: Commands and domain events are separate concepts

Status: Accepted

## Context

LMX accepts writes from humans, crawlers/reconciliation logic, APIs, MCP clients, and AI agents. An attempted mutation is not the same thing as an accepted business fact.

## Decision

Commands represent intent and may be rejected. Accepted commands produce past-tense immutable domain events.

Examples:

- `job_posting.update` -> `job_posting.updated`
- `application.advance` -> `application.stage_changed`
- `job_opening.merge` -> `job_opening.merged`

Source observations are evidence and do not bypass the command/domain boundary.

## Consequences

- validation and authorization remain explicit
- retries can be idempotent
- audit history distinguishes requested actions from accepted facts
- AI agents and parsers cannot silently mutate canonical state
- event consumers depend on facts, not attempted actions
