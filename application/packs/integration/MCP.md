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

The current MCP `2026-07-28` era is stateless and supports:

- `server/discover`
- `tools/list`
- `tools/call`

Every modern request carries `io.modelcontextprotocol/protocolVersion` and `io.modelcontextprotocol/clientCapabilities` in `_meta`. Modern results are stamped with `resultType = complete` and the LMX server identity. `tools/list` is deterministic and returns private cache hints.

`ping` remains available only on the legacy handshake lifecycle. The stdio runtime accepts `2025-11-25`, `2025-06-18`, and `2025-03-26`; one stdio connection locks to either the modern or legacy lifecycle so state from the two protocol eras cannot be mixed.

## Remote HTTP transport

LMX exposes `POST /mcp` as a stateless modern MCP HTTP endpoint. A fresh authenticated runtime is composed for each HTTP request, so there is no `Mcp-Session-Id`, sticky-session requirement, GET event stream, or DELETE session lifecycle.

For ordinary JSON-RPC requests the HTTP boundary requires and validates the standard modern headers against the body:

- `MCP-Protocol-Version: 2026-07-28`
- `Mcp-Method`
- `Mcp-Name` for `tools/call`
- `Content-Type: application/json`

Header/body disagreement returns HTTP 400 with MCP `-32020` (`HeaderMismatch`). Unsupported protocol versions return HTTP 400 with `-32022`. JSON-RPC parse, invalid-request, and invalid-params protocol failures also map to HTTP 400; normal tool and method outcomes remain JSON-RPC responses.

The transport rejects request bodies larger than 4 MiB, rejects hosts not present in `LMX_MCP_HTTP_ALLOWED_HOSTS`, and rejects any browser `Origin` that is not explicitly present in `LMX_MCP_HTTP_ALLOWED_ORIGINS`. Non-browser clients that omit `Origin` are allowed after host and bearer authentication succeed. Wildcard host/origin configuration is intentionally refused.

Client-to-server notification POSTs are accepted without the modern standard-header presence requirement and return HTTP 202 with no body.

## Bootstrap bearer authentication

The first remote-auth slice uses pre-shared high-entropy bearer secrets. Raw bearer secrets are not stored in LMX configuration. `LMX_MCP_HTTP_CREDENTIALS` stores SHA-256 token digests plus trusted identity and capability metadata.

Generate a token and digest, then retain the token only in the MCP client/secret store:

```sh
TOKEN="$(openssl rand -hex 32)"
TOKEN_SHA256="$(printf %s "$TOKEN" | shasum -a 256 | awk '{print $1}')"
```

Example server configuration:

```sh
export LMX_MCP_HTTP_CREDENTIALS="[{
  \"token_sha256\": \"$TOKEN_SHA256\",
  \"workspace_id\": \"org_...\",
  \"principal\": \"user:serhii\",
  \"credential\": \"mcp-http:chatgpt\",
  \"actor\": \"human:serhii\",
  \"executor\": \"agent:chatgpt\",
  \"client\": \"chatgpt\",
  \"capabilities\": [
    \"read:openings\",
    \"read:candidates\",
    \"read:matches\",
    \"submit:openings\",
    \"assess:matches\"
  ]
}]"
export LMX_MCP_HTTP_ALLOWED_HOSTS="lmx.example.com"
```

If a browser-based MCP client is intentionally supported, configure exact origins separately:

```sh
export LMX_MCP_HTTP_ALLOWED_ORIGINS="https://client.example.com"
```

Requests use:

```http
Authorization: Bearer <raw token>
```

Missing or invalid credentials receive HTTP 401 with `WWW-Authenticate: Bearer realm="lmx-mcp"`. The credential entry, not tool arguments or MCP `_meta`, supplies workspace, principal, credential reference, actor/executor provenance, trusted client label, and server-side capabilities.

This bootstrap bearer mechanism is deliberately not presented as full MCP OAuth. Automatic OAuth 2.1 authorization-server discovery, RFC 9728 Protected Resource Metadata, token issuance/refresh/revocation, and scope step-up remain a later slice. Clients that require the MCP OAuth discovery flow will need that follow-up rather than this pre-shared token mode.

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

Write calls may supply `com.lmx/idempotencyKey` inside MCP `_meta`. That key is combined with the trusted workspace/principal/credential/client identity and tool name to derive the durable Inbox command identity. The local stdio runtime retains its runtime-scoped JSON-RPC ID fallback, but the stateless HTTP endpoint requires `com.lmx/idempotencyKey` for every write tool because a JSON-RPC request ID alone is not a durable cross-request identity.

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

Neither stdio nor HTTP bypasses those adapters. The transport layer validates protocol framing and trusted runtime identity, then calls the same Integration read/command boundary.

Still intentionally absent:

- MCP OAuth 2.1 authorization server/resource metadata flow
- persisted agent credential issuance, rotation, revocation, and capability administration
- browser CORS/preflight support for arbitrary web MCP clients
- MCP resources/prompts/subscriptions/tasks
- direct ActiveRecord access from MCP

Those are later transport and composition slices and should not change the shared command/query semantics.
