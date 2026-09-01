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

External write operations become commands. API handlers must not bypass the domain model.

## MCP

MCP is a first-class adapter into the same application command/query layer used by HTTP and the web application.

Expected clients include:

- Grok Bot
- ChatGPT
- Codex
- Anthropic/Claude clients
- custom agents

MCP clients are not granted direct database access. Tools resolve to queries or commands, with authentication, authorization, idempotency, evidence/provenance, and auditability.

Conceptual flow:

```text
Grok Bot -----+
ChatGPT ------+
Codex --------+--> LMX MCP --> application commands/queries --> domain
Claude -------+
custom agents +
```

## Ingress interfaces

Ingress interfaces are different from source-acquisition transports.

Supported/planned ingress classes:

- web/manual
- HTTP API
- webhook
- MCP
- import

All write-capable ingress interfaces converge on Transactional Inbox + application command handling.

## Provenance for agent actions

Every write should record, where applicable:

- principal
- credential reference
- actor
- executor
- client/interface
- correlation_id
- command_id
- evidence/source references

Example:

```text
principal = user:serhii
actor = human:serhii
executor = agent:chatgpt
client = mcp:chatgpt
```

Example:

```text
principal = service:grok-scout
actor = agent:grok-scout
executor = agent:grok-scout
client = mcp:grok-bot
```

This makes multiple autonomous or semi-autonomous agents safe to audit and compare.

## Authorization

Tool-level permissions should distinguish read, submit, annotate, update, application workflow, identity-resolution, and administrative operations. Agent identity alone should never imply unrestricted write access.

Identity-resolution operations such as merge, unlink, relink and merge-revert should use stricter permissions than ordinary annotation.

## Idempotency

MCP and HTTP callers must supply or receive stable request/command identifiers for writes. Retries must not duplicate events or application actions.
