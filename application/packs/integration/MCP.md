# MCP runtime and adapters

The MCP layer is intentionally thin. It exposes shared Integration read and command contracts without owning domain logic or persistence.

```text
MCP client
    |
    v
MCP protocol/runtime
    |
    +--> trusted runtime identity / credential source
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

## Protocol runtime

`Integration::Mcp::Server` is an executable protocol boundary rather than only a set of adapter classes.

It supports the current MCP `2026-07-28` lifecycle for:

- `server/discover`
- `ping`
- `tools/list`
- `tools/call`

Modern requests are stateless at the protocol layer. Each ordinary request carries `io.modelcontextprotocol/protocolVersion` and `io.modelcontextprotocol/clientCapabilities` in `_meta`. Modern results are stamped with `resultType = complete` and the LMX server identity. `tools/list` is deterministic and returns the required private cache hints.

The stdio runtime also accepts the legacy handshake lifecycle for `2025-11-25`, `2025-06-18`, and `2025-03-26`. One stdio connection locks to either the modern or legacy lifecycle so state from the two protocol eras cannot be mixed.

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

`Integration::Mcp::CommandTools` publishes versioned command contracts from the same server-owned schemas used by other ingress adapters.

Current write tools:

- `matches.assess` - records a versioned MatchAssessment, requires `assess:matches`
- `openings.submit` - submits a URL-backed or no-URL opportunity, requires `submit:openings`

`openings.submit` accepts only domain input such as title, company, URL, location, remote policy, compensation, and notes. Principal, credential, actor, executor, interface, client, command identity, and correlation metadata come from the trusted MCP runtime rather than tool arguments.

The opening submission command uses `MarketCatalog::Api.submit_opening`. Canonical URL identity is reused across distinct submissions, while command retries are handled by the Integration Transactional Inbox. MCP-originated records retain `ingress_interface = mcp`; they are not mislabeled as browser/manual submissions.

Write calls may supply `com.lmx/idempotencyKey` inside MCP `_meta`. That key is combined with the trusted workspace/principal/credential/client identity and tool name to derive the durable Inbox command identity, so a retry remains the same command even when the JSON-RPC request ID or stdio process changes. When the client does not supply that key, LMX falls back to the JSON-RPC request ID scoped to the current runtime process. The fallback is replay-safe within one stdio session without creating accidental collisions when another client process later reuses the same JSON-RPC IDs.

## Trusted local runtime identity

The stdio entrypoint is `bin/lmx-mcp`. Run it through Ruby so executable file mode is not required:

```sh
LMX_MCP_WORKSPACE_ID=org_... \
LMX_MCP_PRINCIPAL=user:serhii \
LMX_MCP_CREDENTIAL=credential:local-codex \
LMX_MCP_ACTOR=human:serhii \
LMX_MCP_EXECUTOR=agent:codex \
LMX_MCP_CLIENT=codex \
LMX_MCP_CAPABILITIES='read:openings read:candidates read:matches submit:openings assess:matches' \
bundle exec ruby bin/lmx-mcp
```

`LMX_MCP_WORKSPACE_ID`, `LMX_MCP_PRINCIPAL`, `LMX_MCP_CREDENTIAL`, and `LMX_MCP_CAPABILITIES` are required. Actor defaults to principal; executor and client have local stdio defaults.

The process configuration is the trusted source of identity and capabilities. Capability claims are never accepted from tool arguments or the MCP request `_meta` envelope.

## Adapter behavior

Read and command adapters return the complete Integration outcome as MCP `structuredContent`, mirror it as JSON text content for model consumption, and set `isError` for stable tool failures.

The protocol runtime does not bypass those adapters. It only validates MCP framing/lifecycle, constructs trusted Integration contexts, registers tool definitions, and routes calls.

Still intentionally absent:

- Streamable HTTP transport and `/mcp` endpoint
- HTTP authentication/OAuth and Origin/Host validation
- persisted agent credentials and capability administration
- MCP resources/prompts/subscriptions/tasks
- direct ActiveRecord access from MCP

Those are later transport and composition slices and should not change the shared command/query semantics.
