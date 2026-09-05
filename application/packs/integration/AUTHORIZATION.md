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

The required capability is metadata on the versioned Integration contract. Write capabilities are deliberately distinct from read capabilities. `read:openings` does not imply `submit:openings`, and `read:matches` does not imply `assess:matches`.

## Trust boundary

Capabilities are never accepted from MCP/HTTP/CLI request arguments or client-supplied payloads.

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

Both paths require returned authorization evidence to match the exact `workspace_id`, `principal`, and `credential` from trusted context. An unknown, expired, or revoked credential resolves to `nil`. Malformed or identity-mismatched evidence is a `contract_violation`, never an implicit grant.

## Credential sources

The credential source is intentionally server-side. MCP, HTTP, CLI, and agent clients never provide their own capability arrays. Sources can be backed by:

- trusted local stdio runtime identity
- HTTP bootstrap bearer credentials
- externally verified OAuth tokens plus persisted Integration-owned OAuth grants
- service credentials with workspace-specific grants
- composition that intersects credential or token scope with Workspace authorization facts

The authorization contract does not depend on which authentication mechanism produced the trusted identity.

## Remote MCP OAuth authentication

LMX is an OAuth protected resource, not an OAuth authorization server. It publishes RFC 9728 Protected Resource Metadata and validates externally issued access tokens with RFC 7662 token introspection against the configured authorization-server issuer.

An introspected token is usable only after all token checks pass, including active status, subject, client ID, non-empty scope, exact MCP resource audience, expiration when supplied, and issuer consistency when supplied.

Persisted `integration_mcp_oauth_grants` records map the external identity tuple `(issuer, subject, client_id)` to trusted local `workspace_id`, principal, credential reference, actor/executor provenance, client label, and a maximum Integration capability set. No bearer token or OAuth client secret is stored in the grant table.

OAuth scopes are not a second independent authorization system. For a typed Workspace user, effective runtime access is:

```text
verified OAuth token scopes
          INTERSECTION
persisted Integration capabilities
          INTERSECTION
current Workspace membership capabilities
          =
RuntimeIdentity capabilities
```

A broad OAuth token cannot expand a stored LMX grant. A broad stored grant cannot bypass a narrow token. A stored user grant cannot outlive Workspace membership deactivation or role reduction.

An introspection outage is surfaced as service unavailable rather than as an invalid-credential decision, avoiding accidental fail-open behavior.

## First-contact OAuth pairing

A valid externally issued OAuth token proves an external identity, but it does not by itself decide which LMX workspace user that identity may act as. LMX therefore has a local first-contact pairing step after OAuth verification.

When an introspected token is valid and its `(issuer, subject, client_id)` tuple is completely unknown to both the persisted registry and the legacy migration mapping, LMX may return HTTP 403 with `mcp_pairing_required` and a short-lived browser pairing URL.

The pairing ticket is encrypted and authenticated with the Rails application key. It contains only already-verified identity facts and scopes, never the OAuth bearer token. It is bound to the configured `LMX_MCP_OAUTH_RESOURCE` and expires no later than 15 minutes and no later than the verified access token expiration. The browser URL is derived from the configured MCP resource, not from the inbound Host header.

A signed-in active `workspace_admin` opens the pairing page, selects the local Workspace member the external identity may act as, and explicitly selects a capability subset. Approval is narrowing only:

```text
verified pairable token scopes
          INTERSECTION
admin-selected capabilities
          INTERSECTION
current Workspace role maximum
          =
persisted user grant ceiling
```

Approval enters through `Integration::McpOauthPairing` and then `McpOauthGrantRegistry.create_membership_grant`, so the target membership, manager membership, Workspace policy, external identity uniqueness, and append-only audit event are all revalidated server-side.

Pairing is only for a completely new external identity. If a persisted or legacy tuple is already known but is revoked, blocked by Workspace membership, or has no effective capability intersection, LMX remains unauthorized and does not issue a new pairing ticket. This prevents revocation or role reduction from being bypassed by simply pairing again.

The pairing URL is preserved through LMX sign-in and, for users with multiple workspaces, workspace selection. Possession of the pairing URL alone grants nothing. A current authenticated `workspace_admin` must approve it before a local grant exists.

This local pairing step is separate from OAuth authorization-server consent, token issuance, refresh tokens, and client registration. Those remain responsibilities of the configured OAuth authorization server.

## Workspace membership composition

Workspace remains the owner of membership identity and role facts. `Workspace::Api.fetch_membership` and `fetch_membership_for_user` expose immutable authorization snapshots without exposing `Membership` ActiveRecord objects across the package boundary.

`Integration::Mcp::WorkspaceGrantPolicy` translates those facts into the maximum capabilities current workspace-wide MCP contracts may receive. The allowlist is explicit rather than generated automatically from the contract registry, so adding a new MCP capability never grants it to existing roles by accident.

Current policy:

| Workspace membership | Current workspace-wide MCP maximum |
| --- | --- |
| active `workspace_admin` | all current read/write MCP capabilities |
| active `recruiting_ops_lead` | all current read/write MCP capabilities |
| active `recruiter` | all current read/write MCP capabilities |
| inactive membership | none |
| `client_hiring_manager` | none |
| `client_interviewer` | none |

Client roles are intentionally denied at this layer because existing MCP contracts are workspace-wide while client authorization is client-company and record scoped. Client MCP access should be introduced through client-scoped contracts that preserve those constraints rather than by granting broad workspace capabilities.

Only an active `workspace_admin` may administer policy-bound persisted OAuth grants. `create_membership_grant` derives the local principal and actor from the target membership, checks the requested subset against `WorkspaceGrantPolicy`, and records the managing membership in audit history. Capability updates repeat the manager and target checks.

`Mcp::PersistedOauthGrantStore` re-resolves current Workspace membership on every OAuth-authenticated request for a typed `user` principal. Membership deactivation or role change therefore takes effect without rewriting the grant or restarting the process.

The lower-level `create_grant` and `update_capabilities` operations remain available for trusted migrations and non-user service principals. A typed user principal created through that path is still constrained dynamically at runtime.

## Persisted grant lifecycle and audit

`Integration::McpOauthGrantRegistry` is the trusted application boundary for OAuth grant administration. It supports raw and membership-constrained creation and capability updates, revoke, restore, list, and history. Every management write appends an immutable `integration_mcp_oauth_grant_events` snapshot.

Revocation is a local LMX authorization fact. `Mcp::PersistedOauthGrantStore` only resolves active records, so revoking a grant takes effect on the next OAuth-authenticated request without process restart or environment reload.

The persisted grant registry is intentionally looked up before Workspace context exists. Requiring organization RLS for the table would be circular because LMX learns the workspace from the verified external identity mapping itself. The table therefore acts as a pre-authentication identity registry rather than a recruiting-domain tenant table. Administration still resolves an explicit workspace through `Workspace::Api`, and a foreign key keeps every grant attached to a real workspace.

`LMX_MCP_OAUTH_GRANTS` remains only as an optional migration fallback. Persisted active grants are authoritative when present. New production user grants should use the membership-constrained persisted path.

## Workspace admin control plane

`GET /settings/agent-access` is the browser control plane for persisted MCP OAuth access. It is hidden from non-admin Workspace members, and all management mutations recheck the current active `workspace_admin` membership before touching the registry.

The page keeps revoked grants visible and separates authorization into distinct layers:

- token scopes, verified at request time and intentionally not persisted in the UI
- stored grant capabilities, the local maximum for the external identity
- current Workspace maximum, recomputed from the target membership
- effective local ceiling before request-time token scopes are applied

For membership-bound grants, admins can narrow or expand the stored capability set only inside current Workspace policy. Revocation and restoration record the managing membership in the existing append-only history.

Trusted service-principal grants are visible and revocable from the same control plane, but their capability ceiling is intentionally read-only there because it is not derived from a Workspace role.

`GET /settings/agent-access/pair` is the first-contact approval surface for a short-lived verified pairing ticket. It creates a new membership-bound external identity mapping only after explicit admin approval.

## Write authorization and idempotency

For `matches.assess.v1` and `openings.submit.v1`, authorization is evaluated before `Workspace::Api.with_workspace`, before Transactional Inbox receipt, and before the owning bounded-context command executes. A denied caller creates no command record and no domain mutation.

After authorization, stable `message_id`, `command_id`, and `idempotency_key` values plus principal/credential and actor/executor provenance enter the Platform reliability boundary. Retrying the identical command reconstructs the prior result. Reusing its identity with a different payload fails explicitly.

Tool discovery is not the security boundary. A client may know a write tool exists and still receive `unauthorized` when its server-resolved grant lacks the required capability.

## Still intentionally deferred

- local JWT/JWKS access-token verification as an alternative to online introspection
- LMX-hosted OAuth authorization-server login, consent, token issuance, refresh-token, or client-registration responsibilities
- persisted bootstrap bearer credential issuance, rotation, revocation, and secret verification
- client-scoped MCP contracts that preserve client-company/record-level authorization
- a public HTTP API for capability administration
- stricter identity-resolution capabilities

These can be added behind the existing authentication, pairing, credential-source, and authorization boundaries without changing the versioned read or command contracts.
