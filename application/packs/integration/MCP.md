# MCP read adapter

The MCP layer is intentionally thin. It exposes the shared Integration read contracts without owning domain logic, persistence, authentication, or authorization policy.

```text
MCP transport/runtime
        |
        v
Integration::Mcp::ContextFactory
Integration::Mcp::ReadAdapter
        |
        v
Integration::Read::Dispatcher
        |
        +--> CapabilityAuthorization
        |          |
        |          v
        |    CapabilityResolver
        |
        v
query port -> owning package public query implementation
```

`Integration::Mcp::ReadTools` publishes the current read contracts as MCP tool definitions using the JSON Schema owned by each `Integration::Read::Contract`.

Current tools:

- `openings.search`
- `openings.get`
- `candidates.get`
- `candidates.profile`
- `matches.get`
- `applications.get`

`candidates.profile` returns the latest canonical CandidateProfileVersion for the supplied Candidate ID through `TalentProfile::Api`. It uses the same `read:candidates` capability as candidate identity reads.

`applications.get` is a declared contract but remains intentionally unregistered until canonical Personal CRM exists. The other tools above have production-shaped public-API adapters.

The adapter returns the complete Integration outcome as MCP `structuredContent`, mirrors it as JSON text content for model consumption, and sets `isError` for stable contract failures.

`ContextFactory` fixes `interface` to `mcp` while accepting authenticated principal/credential identity and actor/executor/client provenance from the future runtime composition layer.

Capability claims are never accepted from MCP tool arguments. Execution authorization is performed server-side through `Integration::Read::CapabilityAuthorization` and a concrete `Integration::Read::Ports::CapabilityResolver`.

Still intentionally absent:

- MCP HTTP or stdio server lifecycle
- protocol negotiation/discovery implementation
- authentication middleware
- direct ActiveRecord access
- canonical Personal CRM query implementation
- write tools and Transactional Inbox/Outbox handling

Those are composition/runtime concerns and should be added without changing the shared read contract semantics.
