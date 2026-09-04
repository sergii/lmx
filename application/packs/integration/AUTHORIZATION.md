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

OAuth scopes are not a second independent authorization system. Effective capabilities are the intersection of verified token scopes, persisted server-side capabilities, and, for typed workspace users, current Workspace membership authorization:

```text
verified OAuth token scopes
          ∩
persisted Integration capabilities
          ∩
current Workspace membership capabilities
          =
RuntimeIdentity capabilities
```

A broad OAuth token therefore cannot expand an LMX grant, and a broad stored grant cannot outlive a Workspace role reduction or membership deactivation for a typed user principal.

A token that is active at the external authorization server but has no active local identity grant is treated as unauthenticated. An introspection outage is surfaced as service unavailable rather than as an invalid-credential decision, avoiding accidental fail-open or misleading 401 responses.

## Workspace membership composition

Workspace remains the owner of membership identity and role facts. `Workspace::Api.fetch_membership` and `fetch_membership_for_user` expose immutable authorization snapshots without exposing `Membership` ActiveRecord objects across the package boundary.

`Integration::Mcp::WorkspaceGrantPolicy` translates those facts into the maximum capabilities that current workspace-wide MCP contracts may receive. The allowlist is explicit rather than derived automatically from the contract registry, so adding a new MCP capability never grants it to an existing role by accident.

Current policy:

| Workspace membership | Current workspace-wide MCP maximum |
| --- | --- |
| active `workspace_admin` | all current read/write MCP capabilities |
| active `recruiting_ops_lead` | all current read/write MCP capabilities |
| active `recruiter` | all current read/write MCP capabilities |
| inactive membership | none |
| `client_hiring_manager` | none |
| `client_interviewer` | none |

The client roles are intentionally denied at this layer because the existing MCP contracts are workspace-wide while client authorization is resource/client-company scoped in ActionPolicy. Client MCP access should be introduced through client-scoped contracts that can preserve those record-level constraints rather than by granting broad workspace capabilities.

Only an active `workspace_admin` may administer policy-bound persisted OAuth grants. `McpOauthGrantRegistry.create_membership_grant` derives the local principal and actor from the target membership, checks the requested subset against `WorkspaceGrantPolicy`, and records the managing membership in audit history. `update_membership_capabilities` repeats the manager and target checks before changing the stored maximum.

`Mcp::PersistedOauthGrantStore` re-resolves current Workspace membership on every OAuth-authenticated request when the persisted principal is a typed `user` ID. Membership deactivation or a role change therefore takes effect without rewriting the grant or restarting the process.

The lower-level `create_grant` / `update_capabilities` operations remain available for trusted migration and non-user service-principal composition. A stored typed user principal is still constrained dynamically at runtime even if the record was created through that lower-level path.

## Persisted grant lifecycle and audit

`Integration::McpOauthGrantRegistry` is the trusted application boundary for OAuth grant administration. It supports raw create/capability-update operations, policy-bound membership create/update operations, revoke, restore, list, and history. Management writes append immutable `integration_mcp_oauth_grant_events` snapshots.

Revocation is a local LMX authorization fact. `Mcp::PersistedOauthGrantStore` only resolves active records, so revoking a grant takes effect on the next OAuth-authenticated request without process restart or environment reload. Updating grant capabilities changes the stored maximum authorization envelope in the same way.

The persisted grant registry is intentionally looked up before workspace context exists. Requiring organization RLS for this table would be circular because LMX learns the workspace from the verified external identity mapping itself. The table therefore acts as a pre-authentication identity registry rather than a recruiting-domain tenant table. Administration still resolves an explicit workspace with `Workspace::Api` and scopes every managed read or mutation to that organization. A foreign key keeps every grant attached to a real workspace.

`LMX_MCP_OAUTH_GRANTS` remains only as an optional migration fallback. Persisted active grants are authoritative when present; new production user grants should use the membership-constrained registry path instead of JSON environment configuration.

## Roles versus capabilities

Workspace roles remain an authorization implementation concern and are not copied into versioned Integration contracts. The translation happens only at trusted server-side composition.

Do not map every active Workspace membership directly to global Integration capabilities. Some roles are resource-scoped while agent-facing contracts may be workspace-scoped. `WorkspaceGrantPolicy` intentionally grants the existing broad tools only to the same internal membership class that current ActionPolicy rules treat as internal, and fails closed for client-scoped memberships.

## Write authorization and idempotency

For `matches.assess.v1` and `openings.submit.v1`, authorization is evaluated before `Workspace::Api.with_workspace`, before Transactional Inbox receipt, and before the owning bounded-context command executes. A denied caller therefore creates no command record and no domain mutation.

After authorization, stable `message_id`, `command_id`, and `idempotency_key` values plus principal/credential and actor/executor provenance enter the Platform reliability boundary. Retrying the identical command reconstructs the prior result; reusing its identity with a different payload fails explicitly.

Tool discovery is not the security boundary. A client may know that `openings.submit` or `matches.assess` exists and still receive `unauthorized` when its server-resolved grant lacks the corresponding write capability.

## Still intentionally deferred

- local JWT/JWKS verification as an alternative to online token introspection
- persisted bootstrap bearer credential issuance, rotation, revocation, and secret verification
- client-scoped MCP contracts that preserve client-company/record-level ActionPolicy constraints
- browser/admin UI or public HTTP API for capability administration
- stricter identity-resolution capabilities

These can be added behind the existing credential-source and authentication boundaries without changing the versioned read or command contracts.
