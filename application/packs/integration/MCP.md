# MCP adapters

The MCP layer is intentionally thin. It exposes shared Integration read and command contracts without owning domain logic, persistence, authentication, or authorization policy.

```text
MCP transport/runtime
        |
        v
Integration MCP context + adapter
        |
        +--> Read::Dispatcher ----> read authorization ----> owning package query API
        |
        +--> Command::Dispatcher -> write authorization -> Workspace scope
                                      |
                                      v
                               Transactional Inbox
                                      |
                                      v
                               CommandExecutor
                                      |
                                      v
                               owning package command API
```

## Read tools

`Integration::Mcp::ReadTools` publishes the current read contracts as MCP tool definitions using the JSON Schema owned by each `Integration::Read::Contract`.

Current read tools:

- `openings.search`
- `openings.get`
- `candidates.get`
- `candidates.profile`
- `matches.get`
- `applications.get`

`candidates.profile` returns the latest canonical CandidateProfileVersion for the supplied Candidate ID through `TalentProfile::Api`. It uses the same `read:candidates` capability as candidate identity reads.

`applications.get` is declared but remains intentionally unregistered until its canonical Personal CRM query adapter is complete. The other read tools above have production-shaped public-API adapters.

## Write tools

`Integration::Mcp::CommandTools` publishes versioned command contracts from the same server-owned schemas used by other future ingress adapters.

Current write tools:

- `matches.assess` - records a versioned MatchAssessment, requires `assess:matches`
- `openings.submit` - submits a URL-backed or no-URL opportunity, requires `submit:openings`

`openings.submit` accepts only domain input such as title, company, URL, location, remote policy, compensation, and notes. Principal, credential, actor, executor, interface, client, command identity, and correlation metadata come from the trusted MCP context rather than tool arguments.

The opening submission command uses `MarketCatalog::Api.submit_opening`. Canonical URL identity is reused across distinct submissions, while command retries are handled by the Integration Transactional Inbox. MCP-originated records retain `ingress_interface = mcp`; they are not mislabeled as browser/manual submissions.

## Adapter behavior

Read and command adapters return the complete Integration outcome as MCP `structuredContent`, mirror it as JSON text content for model consumption, and set `isError` for stable contract failures.

`ContextFactory` fixes read `interface` to `mcp`. A future runtime composition layer supplies authenticated principal/credential identity plus actor/executor/client provenance. Command contexts additionally require stable message, command, and idempotency identities before dispatch.

Capability claims are never accepted from MCP tool arguments. Execution authorization is performed server-side through the Integration capability authorization boundary.

Still intentionally absent:

- MCP HTTP or stdio server lifecycle
- protocol negotiation and runtime-level tool registration
- authentication middleware
- persisted agent credentials and capability administration
- direct ActiveRecord access from MCP

Those are composition/runtime concerns and should be added without changing the shared read or command contract semantics.
