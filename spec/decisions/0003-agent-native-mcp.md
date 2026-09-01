# ADR 0003: MCP as a first-class application adapter

Status: Accepted

## Context

Multiple AI agents may read and write LMX data. These may include Grok Bot, ChatGPT, Codex, Claude-compatible clients, and custom agents. Agents must not bypass domain rules or make direct database mutations.

## Decision

Expose MCP as a first-class adapter to the same command/query application layer used by HTTP and the web application.

All writes pass through authentication, authorization, Transactional Inbox/idempotency, domain rules, Event Store, and provenance metadata.

Record actor separately from executor so an agent acting for a human remains auditable.

## Consequences

- agents share one consistent domain contract
- audit history identifies which client caused a change
- retries are safe
- agent permissions can be scoped per tool/action
- future agents can be added without changing the domain model
