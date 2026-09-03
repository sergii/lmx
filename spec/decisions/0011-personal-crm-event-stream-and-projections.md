# ADR 0011: Personal CRM event stream and rebuildable projections

- Status: accepted
- Date: 2026-09-04

## Context

Personal CRM needs both durable workflow history and fast daily views.

The same Candidate can apply to the same JobOpening more than once. Save/ignore decisions, application attempts, stage changes, and next-action changes must remain attributable, replayable, and safe under idempotent retries. At the same time, Opening Detail only needs one Candidate + JobOpening workflow, while Applications list/table/Kanban views need efficient queries across many attempts.

ADR 0001 makes immutable domain events the durable business history where causality and replay matter. ADR 0005 requires reliable command processing through the transactional Inbox/Outbox boundary. ADR 0010 requires cross-package consumers to use explicit public APIs rather than private models.

## Decision

Personal CRM workflow history is event-authoritative.

One `personal_crm_opportunity` stream groups events for a Candidate + JobOpening pair. The stream is a workflow grouping boundary, not the identity of an application attempt.

Each application attempt has its own stable `application_attempt` TypeID. Multiple attempts for the same Candidate + JobOpening are valid and must remain independently addressable.

The stream may contain facts including:

```text
personal_crm.opening.saved
personal_crm.opening.ignored
personal_crm.application.started
personal_crm.application.stage_changed
personal_crm.application.next_action_changed
```

Opening Detail may reduce one opportunity stream directly because the query is bounded to one Candidate + JobOpening pair.

Cross-opportunity views such as Applications list/table/Kanban use Personal CRM-owned read projections when direct event reduction would require broad Event Store scans. A projection is rebuildable derived state, not the system of record. Projection models remain private to the package and are exposed through `PersonalCrm::Api` snapshots.

Commands that change Personal CRM workflow must:

1. enter through the transactional Inbox with an idempotency key and provenance;
2. validate Candidate and JobOpening references through published package APIs;
3. append immutable domain events and transactional Outbox messages;
4. update any synchronous Personal CRM projection in the same transaction as the accepted event when that projection participates in the command path;
5. preserve workspace isolation, including PostgreSQL RLS on Event Store and projection tables.

Projection rebuilds may replay Personal CRM domain events. Rebuild logic must be deterministic for a given event history and must never manufacture new domain events.

## Consequences

- Repeat applications are represented naturally without a Candidate + JobOpening uniqueness constraint.
- Command retries can be idempotent while distinct commands create distinct attempts.
- Audit/history views can explain workflow changes from immutable facts.
- Opening Detail stays simple by reducing one bounded stream.
- Applications workflow can query a purpose-built projection instead of scanning all domain events.
- A projection schema may evolve or be rebuilt without changing accepted workflow history.
- Event schemas and projection reducers become compatibility surfaces and require tests.

## Non-goals

This decision does not require every LMX table to be event sourced. Canonical market snapshots, analytical projections, caches, and other bounded contexts continue to follow their own accepted decisions.
