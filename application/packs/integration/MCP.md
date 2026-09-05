# MCP runtime and adapters

The MCP layer is intentionally thin. It exposes shared Integration read and command contracts without owning recruiting-domain logic.

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

`Integration::Mcp::Server` is an executable protocol boundary. The current MCP `2026-07-28` runtime is stateless and supports `server/discover`, `tools/list`, and `tools/call`.

Every modern request carries `io.modelcontextprotocol/protocolVersion` and `io.modelcontextprotocol/clientCapabilities` in `_meta`. Modern results are stamped with `resultType = complete` and the LMX server identity. `tools/list` is deterministic and returns private cache hints.

`ping` remains available only on the legacy handshake lifecycle. The stdio runtime accepts `2025-11-25`, `2025-06-18`, and `2025-03-26`. One stdio connection locks to either the modern or legacy lifecycle so state from the two protocol eras cannot be mixed.

## Remote HTTP transport

LMX exposes `POST /mcp` as a stateless modern MCP HTTP endpoint. A fresh authenticated runtime is composed for every request, so there is no `Mcp-Session-Id`, sticky-session requirement, GET event stream, or DELETE session lifecycle.

For ordinary JSON-RPC requests the HTTP boundary requires and validates:

- `MCP-Protocol-Version: 2026-07-28`
- `Mcp-Method`
- `Mcp-Name` for `tools/call`
- `Content-Type: application/json`

Header/body disagreement returns HTTP 400 with MCP `-32020` (`HeaderMismatch`). Unsupported protocol versions return HTTP 400 with `-32022`. JSON-RPC parse, invalid-request, and invalid-params failures also map to HTTP 400.

The transport rejects bodies larger than 4 MiB, hosts not present in `LMX_MCP_HTTP_ALLOWED_HOSTS`, and browser origins not present in `LMX_MCP_HTTP_ALLOWED_ORIGINS`. Wildcard host/origin configuration is intentionally refused. Non-browser clients may omit `Origin` after host and bearer authentication succeed.

Client-to-server notification POSTs return HTTP 202 with no body.

## Bootstrap bearer authentication

The bootstrap remote-auth path uses pre-shared high-entropy bearer secrets. Raw secrets are not stored in configuration. `LMX_MCP_HTTP_CREDENTIALS` stores SHA-256 token digests plus trusted identity and capability metadata.

```sh
TOKEN="$(openssl rand -hex 32)"
TOKEN_SHA256="$(printf %s "$TOKEN" | shasum -a 256 | awk '{print $1}')"
```

Example:

```sh
export LMX_MCP_HTTP_CREDENTIALS="[{
  \"token_sha256\": \"$TOKEN_SHA256\",
  \"workspace_id\": \"org_...\",
  \"principal\": \"user:serhii\",
  \"credential\": \"mcp-http:chatgpt\",
  \"actor\": \"human:serhii\",
  \"executor\": \"agent:chatgpt\",
  \"client\": \"chatgpt\",
  \"capabilities\": [\"read:openings\", \"submit:openings\"]
}]"
export LMX_MCP_HTTP_ALLOWED_HOSTS="lmx.example.com"
```

If a browser MCP client is intentionally supported, configure exact origins separately:

```sh
export LMX_MCP_HTTP_ALLOWED_ORIGINS="https://client.example.com"
```

Bootstrap credentials and OAuth introspection can coexist. The runtime tries an exact bootstrap digest match first and then the configured OAuth verifier, keeping the two trust models independent.

## OAuth protected resource discovery

LMX publishes RFC 9728 OAuth 2.0 Protected Resource Metadata for the exact public MCP resource. For `https://lmx.example.com/mcp`, the discovery endpoint is:

```text
https://lmx.example.com/.well-known/oauth-protected-resource/mcp
```

Configure:

```sh
export LMX_MCP_OAUTH_RESOURCE="https://lmx.example.com/mcp"
export LMX_MCP_OAUTH_AUTHORIZATION_SERVERS="https://auth.example.com"
export LMX_MCP_OAUTH_SCOPES="read:openings read:candidates read:matches read:applications submit:openings assess:matches"
export LMX_MCP_OAUTH_RESOURCE_NAME="LMX MCP"
```

When configured, HTTP 401 responses advertise the protected-resource metadata with `WWW-Authenticate`. LMX remains a protected resource rather than becoming an authorization server. Authorization-server login, consent, token issuance, refresh tokens, and client registration stay outside the resource server.

## External OAuth token verification

LMX verifies externally issued OAuth access tokens through RFC 7662 token introspection. This works with opaque or structured access tokens while leaving token format and signing-key policy with the authorization server.

Configure the resource metadata plus:

```sh
export LMX_MCP_OAUTH_INTROSPECTION_ENDPOINT="https://auth.example.com/oauth2/introspect"
export LMX_MCP_OAUTH_INTROSPECTION_CLIENT_ID="lmx-resource-server"
export LMX_MCP_OAUTH_INTROSPECTION_CLIENT_SECRET="..."
```

The introspection request uses HTTP Basic client authentication, includes `token_type_hint=access_token`, never follows redirects, and requires HTTPS.

An introspected token passes the authentication boundary only when:

- `active` is true
- `sub` and `client_id` are non-empty strings
- `scope` is non-empty
- `aud` contains the exact configured MCP resource
- `exp`, when present, is numeric and still in the future
- `iss`, when present, matches the configured authorization-server issuer

The introspection endpoint itself is statically issuer-bound, so omission of `iss` is allowed. If `iss` is supplied, disagreement fails closed.

An authorization-server or introspection outage returns HTTP 503 with `mcp_oauth_unavailable`. Partial verifier configuration fails closed as MCP HTTP configuration unavailable.

## Persisted OAuth identity grants

After token verification, LMX resolves the exact external identity tuple `(issuer, subject, client_id)` in `integration_mcp_oauth_grants`.

```text
(issuer, subject, client_id)
        |
        v
workspace + principal + credential + provenance + capabilities
```

`Integration::McpOauthGrantRegistry` manages lower-level and Workspace-policy-bound grants. It supports creation, capability updates, revoke, restore, list, and history. Every mutation appends an immutable `integration_mcp_oauth_grant_events` snapshot.

The external tuple and `credential` reference are globally unique. No bearer token or OAuth client secret is stored in the table.

For production user grants, `create_membership_grant` derives the trusted local user principal from the selected Workspace membership. Only an active `workspace_admin` may create or update policy-bound grants.

For a typed user principal, effective authorization is recomputed on every OAuth-authenticated request:

```text
verified token scopes
        INTERSECTION
persisted LMX grant capabilities
        INTERSECTION
current Workspace membership capabilities
        =
effective RuntimeIdentity capabilities
```

This means token scope, persisted grant, and current Workspace authorization can only narrow access.

`LMX_MCP_OAUTH_GRANTS` remains an optional legacy JSON migration fallback. New production user mappings should use persisted membership-constrained grants.

## First-contact OAuth pairing

Standard OAuth proves the external token identity but does not decide which local LMX Workspace user that identity may represent. LMX therefore adds a local first-contact pairing step after successful token verification.

If a verified `(issuer, subject, client_id)` tuple is completely unknown and the token includes recognized LMX MCP scopes, `POST /mcp` returns HTTP 403:

```json
{
  "error": "mcp_pairing_required",
  "pairing_url": "https://lmx.example.com/settings/agent-access/pair?pairing_token=...",
  "pairing_expires_at": "..."
}
```

The pairing ticket is encrypted and authenticated by LMX. It contains verified identity facts, scopes, resource, issuance time, and expiration, but never the OAuth bearer token. It is bound to the configured `LMX_MCP_OAUTH_RESOURCE`, and its lifetime is capped at 15 minutes and at the access-token expiration. The URL origin is derived from the configured resource, never from the inbound Host header.

The user opens the pairing URL in a browser. If not signed in, LMX preserves only this known internal return path through authentication. A user with multiple workspaces selects the workspace first. The approval page itself requires an active `workspace_admin`.

The admin then selects:

1. the local active internal Workspace member the external identity may act as
2. an explicit capability subset from the recognized scopes already requested by the verified token

Nothing is selected by default. Approval enters `Integration::McpOauthPairing`, which then calls `McpOauthGrantRegistry.create_membership_grant`. The registry rechecks the manager, target membership, Workspace policy, uniqueness, and audit history before persisting anything.

A known external tuple never becomes pairable again merely because it has no effective access. Revoked grants, role-blocked user grants, scope-mismatched grants, and legacy mappings stay unauthorized. This prevents local revocation from being bypassed by repeating first-contact pairing.

After approval, the MCP client retries with its existing OAuth access token. LMX introspects the token again, resolves the newly persisted grant, intersects all three authorization layers, and builds the trusted runtime identity.

This pairing flow is local LMX authorization. It is not OAuth authorization-server consent and does not replace RFC 9728 discovery or authorization-server client registration.

## Workspace admin control plane

`GET /settings/agent-access` lets a `workspace_admin` inspect persisted OAuth identities, current Workspace authorization, effective local ceilings, and revoked state. Membership-bound capability edits remain constrained by current Workspace policy. Revoke and restore actions are audited.

`GET /settings/agent-access/pair` is the short-lived first-contact approval surface described above.

Service-principal grants remain visible and revocable in the control plane, but their capability ceilings are intentionally read-only there because they are not derived from Workspace roles.

## Read tools

Current read tools:

- `openings.search`
- `openings.get`
- `candidates.get`
- `candidates.profile`
- `matches.get`
- `applications.get`

`candidates.profile` returns the latest canonical CandidateProfileVersion through `TalentProfile::Api` and requires `read:candidates`.

`applications.get` returns the canonical Personal CRM application-attempt projection through `PersonalCrm::Api`, requires `read:applications`, and preserves Personal CRM ownership of application state.

## Write tools

Current write tools:

- `matches.assess` requires `assess:matches`
- `openings.submit` requires `submit:openings`

Principal, credential, actor, executor, interface, client, command identity, and correlation metadata come from trusted MCP runtime identity rather than tool arguments.

Write calls may supply `com.lmx/idempotencyKey` inside MCP `_meta`. The key is combined with trusted workspace/principal/credential/client identity and tool name to derive durable Inbox command identity. The local stdio runtime retains a runtime-scoped JSON-RPC ID fallback, while stateless HTTP requires an explicit durable idempotency key for every write tool.

## Trusted local stdio identity

The stdio entrypoint is `bin/lmx-mcp`:

```sh
LMX_MCP_WORKSPACE_ID=org_... \
LMX_MCP_PRINCIPAL=user:serhii \
LMX_MCP_CREDENTIAL=credential:local-codex \
LMX_MCP_ACTOR=human:serhii \
LMX_MCP_EXECUTOR=agent:codex \
LMX_MCP_CLIENT=codex \
LMX_MCP_CAPABILITIES='read:openings read:candidates read:matches read:applications submit:openings assess:matches' \
bundle exec ruby bin/lmx-mcp
```

`LMX_MCP_WORKSPACE_ID`, `LMX_MCP_PRINCIPAL`, `LMX_MCP_CREDENTIAL`, and `LMX_MCP_CAPABILITIES` are required. Actor defaults to principal. Executor and client have local defaults.

The process configuration is the trusted identity source. Capabilities are never accepted from tool arguments or MCP request `_meta`.

## Adapter behavior

Read and command adapters return the complete Integration outcome as MCP `structuredContent`, mirror it as JSON text for model consumption, and set `isError` for stable tool failures.

Neither stdio nor HTTP bypasses the shared adapters. The transport validates protocol framing and trusted runtime identity, then calls the same Integration read/command boundary.

Still intentionally absent:

- local JWT/JWKS verification as an alternative to RFC 7662 introspection
- LMX-hosted OAuth authorization-server login, consent, token issuance, refresh-token, or client-registration responsibilities
- persisted bootstrap bearer credential issuance, rotation, and secret administration
- client-scoped MCP contracts preserving client-company and record-level authorization
- a public HTTP API for OAuth grant administration
- arbitrary browser CORS/preflight support
- MCP resources, prompts, subscriptions, and tasks
- direct recruiting-domain ActiveRecord access from MCP

Those are later transport and composition slices and should not change the shared command/query semantics.
