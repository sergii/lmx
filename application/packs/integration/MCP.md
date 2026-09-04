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

Header/body disagreement returns HTTP 400 with MCP `-32020` (`HeaderMismatch`). Unsupported protocol versions return HTTP 400 with `-32022`. JSON-RPC parse, invalid-request, and invalid-params failures also map to HTTP 400; normal tool and method outcomes remain JSON-RPC responses.

The transport rejects request bodies larger than 4 MiB, rejects hosts not present in `LMX_MCP_HTTP_ALLOWED_HOSTS`, and rejects any browser `Origin` that is not explicitly present in `LMX_MCP_HTTP_ALLOWED_ORIGINS`. Non-browser clients that omit `Origin` are allowed after host and bearer authentication succeed. Wildcard host/origin configuration is intentionally refused.

Client-to-server notification POSTs are accepted without the modern standard-header presence requirement and return HTTP 202 with no body.

## Bootstrap bearer authentication

The bootstrap remote-auth path uses pre-shared high-entropy bearer secrets. Raw bearer secrets are not stored in LMX configuration. `LMX_MCP_HTTP_CREDENTIALS` stores SHA-256 token digests plus trusted identity and capability metadata.

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
    \"read:applications\",
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

Requests use `Authorization: Bearer <raw token>`. When OAuth resource discovery is not configured, missing or invalid credentials receive HTTP 401 with `WWW-Authenticate: Bearer realm="lmx-mcp"`.

Bootstrap credentials and OAuth introspection can coexist. The HTTP runtime tries an exact bootstrap digest match first and then the configured OAuth verifier. This keeps local/emergency credentials independent from externally issued access tokens without merging their trust models.

## OAuth protected resource discovery

LMX publishes RFC 9728 OAuth 2.0 Protected Resource Metadata for the public MCP resource. Because the protected resource is the exact `https://.../mcp` URL, RFC 9728 inserts its well-known suffix before that resource path:

```text
https://lmx.example.com/mcp
        |
        v
https://lmx.example.com/.well-known/oauth-protected-resource/mcp
```

Configure the discovery document with:

```sh
export LMX_MCP_OAUTH_RESOURCE="https://lmx.example.com/mcp"
export LMX_MCP_OAUTH_AUTHORIZATION_SERVERS="https://auth.example.com"
export LMX_MCP_OAUTH_SCOPES="read:openings read:candidates read:matches read:applications submit:openings assess:matches"
export LMX_MCP_OAUTH_RESOURCE_NAME="LMX MCP"
```

The metadata endpoint returns the exact resource identifier, authorization-server issuer list, `bearer_methods_supported: ["header"]`, optional scopes, and the human-readable resource name. Resource and authorization-server identifiers must use HTTPS and must not contain fragments; the configured resource must identify LMX's actual `/mcp` endpoint.

When this metadata is configured, HTTP 401 responses advertise it using RFC 9728:

```http
WWW-Authenticate: Bearer realm="lmx-mcp", resource_metadata="https://lmx.example.com/.well-known/oauth-protected-resource/mcp", scope="read:openings ..."
```

LMX remains an OAuth protected resource rather than becoming an authorization server. The MCP `2026-07-28` specification deprecates Dynamic Client Registration in favor of Client ID Metadata Documents, so LMX does not build a DCR dependency into the resource server.

## External OAuth access-token verification

The HTTP runtime verifies externally issued OAuth access tokens through an RFC 7662 token introspection endpoint. Introspection works for both opaque and structured access tokens and leaves signing-key and token-format policy with the authorization server instead of duplicating JWT cryptography in LMX.

Configure the resource metadata above plus:

```sh
export LMX_MCP_OAUTH_INTROSPECTION_ENDPOINT="https://auth.example.com/oauth2/introspect"
export LMX_MCP_OAUTH_INTROSPECTION_CLIENT_ID="lmx-resource-server"
export LMX_MCP_OAUTH_INTROSPECTION_CLIENT_SECRET="..."
```

The introspection request uses HTTP Basic client authentication and sends the bearer token plus `token_type_hint=access_token`. LMX does not follow redirects from the configured introspection endpoint. The endpoint must be HTTPS.

An introspected token is accepted only when all of these conditions hold:

- the authorization server reports `active: true`
- `sub` and `client_id` are non-empty strings
- `scope` is non-empty
- `aud` contains the exact configured `LMX_MCP_OAUTH_RESOURCE`
- `exp`, when present, is numeric and still in the future
- `iss`, when present, exactly matches the configured authorization-server issuer
- the exact `(issuer, subject, client_id)` tuple resolves to an active local LMX grant

The introspection endpoint itself is statically bound to the advertised issuer, so an introspection response may omit `iss`; if it supplies `iss`, disagreement fails closed.

A valid token without a matching active local grant receives HTTP 401. An authorization-server/introspection outage receives HTTP 503 with `mcp_oauth_unavailable` so transient verifier failure is not confused with invalid credentials. Partial OAuth verifier configuration fails closed as MCP HTTP configuration unavailable.

The introspection client currently verifies on every OAuth-authenticated HTTP request and does not cache token status. If request volume makes that expensive, a later slice can add bounded caching no longer than token expiry while preserving revocation requirements.

## Persisted OAuth grant registry

Production OAuth identity mappings live in `integration_mcp_oauth_grants`. A grant maps one exact external identity tuple to trusted local execution identity and a maximum capability set:

```text
(issuer, subject, client_id)
        |
        v
workspace + principal + credential + provenance + capabilities
```

`Integration::McpOauthGrantRegistry` is the application boundary for management. It supports lower-level trusted operations and policy-bound workspace-user operations:

- `create_grant`
- `update_capabilities`
- `create_membership_grant`
- `update_membership_capabilities`
- `revoke_grant`
- `restore_grant`
- `list_grants`
- `grant_history`

Every mutation records an append-only `integration_mcp_oauth_grant_events` audit snapshot. Revocation is checked on every OAuth-authenticated HTTP request, so a revoked persisted grant stops resolving immediately without process restart or environment reload.

The external identity tuple and `credential` reference are globally unique. This prevents one bearer token identity from becoming ambiguously mapped to several workspaces. Workspace IDs are backed by an `organizations` foreign key.

The grant table is intentionally a pre-authentication registry rather than an organization-RLS table. The runtime does not know the workspace until it resolves `(issuer, subject, client_id)`, so requiring an existing workspace RLS context would make secure identity lookup circular. No bearer token or OAuth client secret is stored in this table. Management operations still resolve and scope an explicit workspace through `Workspace::Api`.

## Workspace-constrained OAuth grants

For production user grants, use `create_membership_grant` instead of supplying arbitrary local identity strings. The target membership supplies the trusted user principal/actor, and the managing membership supplies the audit identity.

Only an active `workspace_admin` may create or update policy-bound OAuth grants. Current broad MCP contracts are workspace-wide, so active `workspace_admin`, `recruiting_ops_lead`, and `recruiter` memberships can receive the current workspace-wide MCP capability set. Inactive memberships and client roles receive no broad MCP capabilities.

Client roles are intentionally fail-closed here because their existing ActionPolicy rules are client-company and record scoped. Granting a workspace-wide MCP tool would discard those constraints. Client MCP access should use future client-scoped contracts instead.

Example from a trusted Rails console or future admin adapter:

```ruby
Integration::McpOauthGrantRegistry.create_membership_grant(
  workspace_id: "org_...",
  membership_id: "membership_target...",
  managed_by_membership_id: "membership_admin...",
  issuer: "https://auth.example.com",
  subject: "external-user-123",
  client_id: "chatgpt-client",
  credential: "mcp-oauth:chatgpt",
  executor: "agent:chatgpt",
  client: "chatgpt",
  capabilities: %w[read:openings submit:openings]
)
```

For a typed `user` principal, effective OAuth authorization is a three-way intersection on every authenticated request:

```text
verified token scopes
        INTERSECTION
persisted LMX grant capabilities
        INTERSECTION
current Workspace membership capabilities
        =
effective RuntimeIdentity capabilities
```

That means an OAuth token cannot expand the stored grant, the stored grant cannot bypass a narrow token, and a stored user grant cannot outlive a Workspace membership deactivation or role reduction. `Integration::Mcp::PersistedOauthGrantStore` re-resolves the current membership for typed user principals before constructing `RuntimeIdentity`.

The explicit `Integration::Mcp::WorkspaceGrantPolicy` allowlist is not generated automatically from the contract registry. Tests deliberately fail when published Integration capabilities and the policy list drift, forcing a review whenever a new capability is introduced.

The lower-level `create_grant` and `update_capabilities` methods remain available for trusted migration and service-principal composition. Typed user principals created through those lower-level operations are still constrained dynamically by current Workspace membership at runtime. Legacy non-TypeID principals preserve their migration behavior and do not pretend to be workspace-user memberships.

For a migration window, `LMX_MCP_OAUTH_GRANTS` remains an optional legacy JSON fallback. The runtime always tries the persisted registry first and consults the legacy mapping only when no persisted active grant matches. New production user grants should use persisted membership-constrained grants instead of JSON mappings.

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

`applications.get` returns the canonical Personal CRM application-attempt projection for the supplied ApplicationAttempt ID through `PersonalCrm::Api`. It requires `read:applications`, enters the trusted workspace scope before lookup, and preserves Personal CRM ownership of attempt identity, stage, next-action, and projection fields.

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
LMX_MCP_CAPABILITIES='read:openings read:candidates read:matches read:applications submit:openings assess:matches' \
bundle exec ruby bin/lmx-mcp
```

`LMX_MCP_WORKSPACE_ID`, `LMX_MCP_PRINCIPAL`, `LMX_MCP_CREDENTIAL`, and `LMX_MCP_CAPABILITIES` are required. Actor defaults to principal; executor and client have local stdio defaults.

The process configuration is the trusted source of identity and capabilities. Capability claims are never accepted from tool arguments or the MCP request `_meta` envelope.

## Adapter behavior

Read and command adapters return the complete Integration outcome as MCP `structuredContent`, mirror it as JSON text content for model consumption, and set `isError` for stable tool failures.

Neither stdio nor HTTP bypasses those adapters. The transport layer validates protocol framing and trusted runtime identity, then calls the same Integration read/command boundary.

Still intentionally absent:

- local JWT/JWKS access-token verification as an alternative to RFC 7662 introspection
- authorization-server login, consent, token issuance, refresh-token, or client-registration responsibilities
- persisted bootstrap bearer credential issuance/rotation and secret administration
- a browser/admin UI or public HTTP API for OAuth grant administration
- client-scoped MCP contracts that preserve client-company/record-level ActionPolicy constraints
- browser CORS/preflight support for arbitrary web MCP clients
- MCP resources/prompts/subscriptions/tasks
- direct recruiting-domain ActiveRecord access from MCP

Those are later transport and composition slices and should not change the shared command/query semantics.
