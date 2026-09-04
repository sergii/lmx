# Integration capability authorization

Integration authorization is capability-based at the agent-facing boundary. It does not expose or duplicate Rails role names.

## Stable capabilities

| Contracts | Capability |
| --- | --- |
| `openings.search.v1`, `openings.get.v1` | `read:openings` |
| `openings.submit.v1` | `submit:openings` |
| `candidates.get.v1`, `candidates.profile.v1` | `read:candidates` |
| `matches.get.v1` | `read:matches` |
| `matches.assess.v1` | `assess:matches` |
| `applications.get.v1` | `read:applications` |

The required capability is metadata on the versioned Integration contract. Write capabilities are deliberately distinct from read capabilities; `read:openings` does not imply `submit:openings`, and `read:matches` does not imply `assess:matches`.

## Trust boundary

Capabilities are never accepted from MCP/HTTP/CLI request arguments or from client-supplied payloads.

```text
client request
    |
    | authenticated principal / credential reference / provenance
    v
Integration Context
    |
    v
server-side CredentialSource
    |
    v
workspace/principal/credential-bound capability evidence
    |
    +-- allow -> query/command port
    |
    +-- deny  -> unauthorized
```

For reads, `Integration::Read::CredentialCapabilityResolver` constructs a `CapabilityGrant` from the server-side source and `CapabilityAuthorization` evaluates the contract capability. For commands, `Integration::Command::CapabilityAuthorization` applies the same fail-closed identity binding directly to the command context before any Workspace or Inbox work occurs.

Both paths require returned authorization evidence to match the exact `workspace_id`, `principal`, and `credential` from the trusted context. An unknown, expired, or revoked credential resolves to `nil`; malformed or identity-mismatched evidence is a `contract_violation`, not an implicit grant.

## Credential source boundary

The credential source is intentionally server-side. MCP, HTTP, CLI, and agent clients never provide their own capability arrays. Sources can be backed by:

- the trusted local stdio runtime identity
- the HTTP bootstrap bearer credential store
- externally verified OAuth tokens plus persisted Integration-owned OAuth grants
- service credentials with workspace-specific grants
- a composition layer that intersects credential or token scope with Workspace authorization facts

The authorization contract does not depend on which persistence or authentication mechanism is selected.

## Remote MCP authentication

The HTTP MCP boundary supports two independent bearer-authentication sources.

Bootstrap credentials are pre-shared high-entropy secrets configured server-side as SHA-256 digests. A successful lookup constructs `RuntimeIdentity`, and its credential source feeds the same capability authorization used by all other Integration ingress paths.

For externally issued OAuth access tokens, LMX uses RFC 7662 token introspection against a statically configured HTTPS endpoint associated with the single advertised authorization-server issuer. Active token status is not enough by itself. LMX additionally requires a resource audience containing the exact MCP resource identifier, a subject, a client ID, a non-empty scope string, and a matching active persisted `(issuer, subject, client_id)` grant. An `iss` value returned by introspection must agree with the configured issuer; omission is allowed because the introspection endpoint itself is issuer-bound.

`integration_mcp_oauth_grants` maps the external identity tuple to trusted local `workspace_id`, principal, credential reference, actor/executor provenance, client label, and maximum Integration capabilities. It stores no bearer token and no OAuth client secret. The external tuple and local credential reference are globally unique so one external identity cannot be ambiguously mapped to several workspaces.

OAuth scopes are not a second independent authorization system. Effective capabilities are the exact intersection of verified token scopes and persisted server-side capabilities:

```text
verified OAuth token scopes
          ∩
persisted Integration capabilities
          =
RuntimeIdentity capabilities
```

A broad OAuth token therefore cannot expand an LMX grant, and a broad LMX grant cannot bypass a narrow token. Workspace authorization remains a separate server-side fact beyond this ingress authentication boundary.

A token that is active at the external authorization server but has no active local identity grant is treated as unauthenticated. An introspection outage is surfaced as service unavailable rather than as an invalid-credential decision, avoiding accidental fail-open or misleading 401 responses.

## Persisted grant lifecycle and audit

`Integration::McpOauthGrantRegistry` is the trusted application boundary for OAuth grant administration. It supports create, capability update, revoke, restore, list, and history operations. Management writes require an explicit `managed_by` identity and append immutable `integration_mcp_oauth_grant_events` snapshots.

Revocation is a local LMX authorization fact. `Mcp::PersistedOauthGrantStore` only resolves active records, so revoking a grant takes effect on the next OAuth-authenticated request without process restart or environment reload. Updating grant capabilities changes the maximum authorization envelope in the same way.

The persisted grant registry is intentionally looked up before workspace context exists. Requiring organization RLS for this table would be circular because LMX learns the workspace from the verified external identity mapping itself. The table therefore acts as a pre-authentication identity registry rather than a recruiting-domain tenant table. Administration still resolves an explicit workspace with `Workspace::Api.with_workspace` and scopes every managed read or mutation to that organization. A foreign key keeps every grant attached to a real workspace.

`LMX_MCP_OAUTH_GRANTS` remains only as an optional migration fallback. Persisted active grants are authoritative when present; new production grants should be created through the registry instead of JSON environment configuration.

## Roles versus capabilities

Workspace roles such as `workspace_admin`, `recruiter`, or client roles remain an authorization implementation concern and are not copied into Integration contracts.

Do not map every active Workspace membership directly to global Integration capabilities. Some roles are resource-scoped while agent-facing contracts may be workspace-scoped. Trusted authorization composition must preserve that distinction.

## Write authorization and idempotency

For `matches.assess.v1` and `openings.submit.v1`, authorization is evaluated before `Workspace::Api.with_workspace`, before Transactional Inbox receipt, and before the owning bounded-context command executes. A denied caller therefore creates no command record and no domain mutation.

After authorization, stable `message_id`, `command_id`, and `idempotency_key` values plus principal/credential and actor/executor provenance enter the Platform reliability boundary. Retrying the identical command reconstructs the prior result; reusing its identity with a different payload fails explicitly.

Tool discovery is not the security boundary. A client may know that `openings.submit` or `matches.assess` exists and still receive `unauthorized` when its server-resolved grant lacks the corresponding write capability.

## Still intentionally deferred

- local JWT/JWKS verification as an alternative to online token introspection
- persisted bootstrap bearer credential issuance, rotation, revocation, and secret verification
- concrete Workspace/ActionPolicy-to-grant composition
- browser/admin UI or public API for capability administration
- stricter identity-resolution capabilities

These can be added behind the existing credential-source and authentication boundaries without changing the versioned read or command contracts.
