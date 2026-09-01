# ADR 0001: Event sourcing for market and workflow history

Status: Accepted

## Context

The product must answer historical questions that cannot be reconstructed reliably from current rows: when an opening appeared, where it was republished, what changed, whether it disappeared and reopened, who changed a record, and which actor or parser caused a mutation.

## Decision

Use immutable domain events as the durable business history for state transitions that matter to the product.

Commands express intent. Accepted commands produce domain events. Read models and audit views are projections.

The system does not need to force every cache or derived analytical table into pure event sourcing. Event sourcing is used where history, causality, replay, and auditability create product value.

## Consequences

Positive:

- historical market analysis is native
- auditability for humans, crawlers, parsers, and agents
- causal chains can be inspected
- projections can evolve
- reopen/repost behavior is preserved

Costs:

- event versioning and projection discipline
- idempotency requirements
- more explicit application architecture
- replay and migration tooling
