# Integration read contracts

This package owns transport-neutral read/query contracts that can be shared by MCP, HTTP/API, CLI, and future agent-facing adapters.

LMX remains the system of record. Integration adapters do not read or mutate private ActiveRecord models in other packages.

## Boundary

```text
MCP / HTTP / CLI / agent adapter
            |
            v
Integration::Read::Dispatcher
            |
            +--> Integration::Read::Ports::Authorization
            |
            v
Integration::Read::Ports::Query
            |
            v
owning package public query implementation
```

Typed IDs are treated as opaque public strings by the Integration protocol. Production composition declares explicit Packwerk dependencies only on bounded contexts whose public application APIs it calls: Workspace, Talent Profile, Market Catalog, and Intelligence. Integration does not parse those identifiers through another package's ActiveRecord models or call private constants.

## Versioned v1 contracts

| Contract | Request input | Response data |
| --- | --- | --- |
| `openings.search.v1` | optional `query`, generic `filters`, optional `cursor`, optional positive `limit` | object with `items` array and optional `next_cursor` |
| `openings.get.v1` | required opaque `id` | extensible resource object |
| `candidates.get.v1` | required opaque Candidate `id` | Candidate resource object |
| `candidates.profile.v1` | required opaque Candidate `id` | latest canonical CandidateProfileVersion resource |
| `matches.get.v1` | required opaque MatchAssessment `id` | versioned MatchAssessment resource from Intelligence |
| `applications.get.v1` | required opaque `id` | extensible resource object |

Resource fields remain owned by their bounded contexts. Integration validates the envelope shape but does not duplicate Market Catalog, Talent Profile, Intelligence, or Personal CRM domain schemas.

`candidates.profile.v1` returns the latest canonical profile version for the requested Candidate. Exact historical profile-version lookup remains an owning Talent Profile API concern and can be exposed as a separate transport contract later if needed.

`matches.get.v1` is deliberately a resource lookup by MatchAssessment ID. Ranked or top-match retrieval should be introduced later as a distinct collection/query contract rather than changing the meaning of this v1 operation.

## Query context and provenance

Every accepted read query carries an `Integration::Read::Context` with:

- `workspace_id` - opaque tenant/workspace identifier
- `principal` - authenticated security identity
- `credential` - non-secret credential reference, never the credential secret itself
- `actor` - logical initiator of the intent
- `executor` - agent/component executing on behalf of the actor
- `interface` - protocol/interface such as `mcp`, `http`, or `cli`
- `client` - client implementation identity such as `chatgpt`, `claude`, or another generic client name
- optional `request_id`
- optional `correlation_id`

Example:

```ruby
context = Integration::Read::Context.new(
  workspace_id: "workspace_01...",
  principal: "user:serhii",
  credential: "session:01...",
  actor: "human:serhii",
  executor: "agent:chatgpt",
  interface: "mcp",
  client: "chatgpt",
  request_id: "request_01...",
  correlation_id: "correlation_01..."
)
```

The full context crosses the internal adapter/port boundary. Response serialization intentionally omits the credential reference while retaining the rest of the provenance context.

## Example request

```ruby
outcome = dispatcher.call(
  name: "openings.search",
  version: 1,
  context: context,
  input: {
    query: "ruby rails",
    filters: { "remote" => true },
    limit: 20
  }
)
```

`filters` is deliberately generic at this layer. Integration must not invent Market Catalog fields before that package publishes them.

## Example success envelope

```ruby
{
  ok: true,
  contract: { name: "openings.search", version: 1 },
  context: {
    workspace_id: "workspace_01...",
    principal: "user:serhii",
    actor: "human:serhii",
    executor: "agent:chatgpt",
    interface: "mcp",
    client: "chatgpt",
    request_id: "request_01...",
    correlation_id: "correlation_01..."
  },
  data: {
    items: [
      { id: "job_opening_01..." }
    ],
    next_cursor: nil
  },
  meta: {
    provenance: {}
  }
}
```

## Errors

Transport adapters receive stable failure semantics through `Integration::Read::Outcome`:

- `invalid_input`
- `unauthenticated`
- `unauthorized`
- `not_found`
- `unsupported`
- `not_implemented`
- `contract_violation` for an Integration port that violates the declared response contract

Example failure envelope:

```ruby
{
  ok: false,
  contract: { name: "candidates.get", version: 1 },
  context: { ... },
  error: {
    code: "not_found",
    message: "Resource not found"
  }
}
```

MCP and HTTP adapters can map these codes to their own transport-specific error/status representation without changing query semantics.

## Authorization

Authentication is represented by `principal` plus a credential reference in the query context. Authorization is a separate port: `Integration::Read::Ports::Authorization`.

Production-shaped composition resolves capabilities from a server-side credential source and checks the contract's required capability before routing the query. Candidate identity and profile reads both require `read:candidates`; `matches.get.v1` requires `read:matches`. Client tool arguments never grant capabilities.

## Intentionally not implemented here

- MCP server/runtime or MCP gem integration
- HTTP routes/controllers
- direct ActiveRecord queries across bounded contexts
- exact historical CandidateProfileVersion transport lookup
- ranked/top MatchAssessment query semantics
- canonical Personal CRM implementation for `applications.get`
- Transactional Inbox/Outbox write handling
- write command metadata such as `command_id`, `idempotency_key`, and `causation_id`

Those pieces can be plugged in later without changing the existing v1 tool/query names or the core query context/error semantics.
