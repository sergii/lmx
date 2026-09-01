# Commands, domain events, integration events, and telemetry

LMX separates four concepts that are often incorrectly mixed together.

## Commands

Commands represent intent. Examples:

```text
job_posting.submit
job_posting.update
job_opening.merge
application.create
application.advance
company.enrich
```

A command can be rejected by authorization, validation, idempotency, or domain rules.

## Domain events

Domain events represent accepted business facts. Examples:

```text
job_posting.discovered
job_posting.updated
job_posting.compensation_changed
job_posting.disappeared
job_posting.reappeared
job_opening.created
job_opening.merged
job_opening.reopened
application.created
application.stage_changed
company.enriched
```

Use past-tense facts for domain events. The distinction is intentional: `job_posting.update` is an instruction, while `job_posting.updated` is a fact.

## Integration events

Integration events are stable, versioned messages for consumers outside a bounded context. They may aggregate or redact internal domain details.

Examples:

```text
lmx.opportunity.high_priority.v1
lmx.posting.changed.v1
lmx.application.stage_changed.v1
```

## Telemetry

Telemetry describes system behavior, not business truth. Examples include crawl latency, parser errors, MCP call duration, queue depth, and notification delivery latency.

Telemetry belongs in the observability stack, not the business Event Store.

## Audit and provenance

Audit views are projections over immutable domain events and command metadata, not a separate mutable source of truth.

A useful audit entry can explain:

- what changed
- previous and new values when relevant
- who initiated the change
- who executed it
- which interface or adapter was used
- which command caused the event
- which earlier event or observation caused the command
- when it happened

## Actor and executor

Actor and executor are separate concepts.

Examples:

```text
actor: human:serhii
executor: agent:chatgpt
```

or:

```text
actor: crawler:source-adapter
executor: system:normalizer
```

Actor types may include human, system, crawler, parser, agent, MCP client, API client, and integration.

This distinction is essential when AI agents operate on behalf of humans.
