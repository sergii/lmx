# ADR 0005: Transactional Inbox and Outbox

Status: Accepted

## Context

LMX receives retried and duplicated writes from APIs, MCP clients, agents, webhooks, and background processing. It also needs reliable asynchronous delivery to Telegram, search, analytics, and external consumers.

## Decision

Use a Transactional Inbox for idempotent external command handling and a Transactional Outbox for reliable publication of integration messages.

A state-changing transaction should atomically persist accepted domain state/events and its outbox records. Retries of the same command identifier must not apply the mutation twice.

## Consequences

- safe retries from agents and integrations
- no dual-write gap between domain commit and asynchronous publication
- observable processing attempts and failures
- delivery consumers can evolve independently
- additional storage and background processing complexity is accepted early because reliability is part of the product model
