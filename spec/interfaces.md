# Interfaces and agents

## API

LMX should expose a versioned API for machine and human tooling.

Candidate capabilities:

```text
openings.search
openings.get
postings.submit
postings.get
postings.update
companies.get
companies.enrich
applications.create
applications.update
applications.advance
market.query
```

External write operations must become commands. API handlers must not bypass the domain model.

## MCP

MCP is a first-class adapter into the same application command/query layer.

Expected clients include:

- Grok Bot
- ChatGPT
- Codex
- Anthropic/Claude clients
- custom agents

MCP clients are not granted direct database access. Tools resolve to queries or commands, with authentication, authorization, idempotency, and provenance.

Conceptual flow:

```text
Grok Bot -----+
ChatGPT ------+
Codex --------+--> LMX MCP --> application commands/queries --> domain
Claude -------+
custom agents +
```

## Provenance for agent actions

Every write should record the initiating actor and executing client where applicable.

Examples:

```text
actor = human:serhii
executor = agent:chatgpt
interface = mcp
```

```text
actor = agent:grok-scout
executor = agent:grok-scout
interface = mcp
```

This makes multiple autonomous or semi-autonomous agents safe to audit and compare.

## Authorization

Tool-level permissions should distinguish read, submit, annotate, update, application workflow, and administrative operations. Agent identity alone should never imply unrestricted write access.

## Idempotency

MCP and HTTP callers must supply or receive stable request/command identifiers for writes. Retries must not duplicate events or application actions.
