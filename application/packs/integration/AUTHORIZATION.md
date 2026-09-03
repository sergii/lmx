# Integration capability authorization

Integration authorization is capability-based at the agent-facing boundary. It does not expose or duplicate Rails role names.

## Stable capabilities

| Contracts | Capability |
| --- | --- |
| `openings.search.v1`, `openings.get.v1` | `read:openings` |
| `candidates.get.v1`, `candidates.profile.v1` | `read:candidates` |
| `matches.get.v1` | `read:matches` |
| `matches.assess.v1` | `assess:matches` |
| `applications.get.v1` | `read:applications` |

The required capability is metadata on the versioned Integration contract. Write capabilities are deliberately distinct from read capabilities; `read:matches` does not imply `assess:matches`.

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

Both paths require the returned authorization evidence to match the exact `workspace_id`, `principal`, and `credential` from the trusted context. An unknown, expired, or revoked credential should resolve to `nil`; malformed or identity-mismatched evidence is a `contract_violation`, not an implicit grant.

## Credential source boundary

The credential source is intentionally server-side. MCP, HTTP, CLI, and agent clients never provide their own capability arrays. A future source may be backed by:

- Integration-owned agent credential persistence and explicit tool grants
- delegated user credentials whose workspace access has already been resolved by trusted authentication/authorization composition
- service credentials with workspace-specific grants
- a composition layer that intersects credential scope with Workspace authorization facts

The authorization contract does not depend on which persistence or authentication mechanism is selected.

## Roles versus capabilities

Workspace roles such as `workspace_admin`, `recruiter`, or client roles remain an authorization implementation concern and are not copied into Integration contracts.

Do not map every active Workspace membership directly to global Integration capabilities. Some roles are resource-scoped while agent-facing contracts may be workspace-scoped. Trusted authorization composition must preserve that distinction.

## Write authorization and idempotency

For `matches.assess.v1`, authorization is evaluated before `Workspace::Api.with_workspace`, before Transactional Inbox receipt, and before Intelligence execution. A denied caller therefore creates no command record and no domain mutation.

After authorization, stable `message_id`, `command_id`, and `idempotency_key` values plus principal/credential and actor/executor provenance enter the Platform reliability boundary. Retrying the identical command reconstructs the prior result; reusing its identity with a different payload fails explicitly.

Tool discovery is not the security boundary. A client may know that `matches.assess` exists and still receive `unauthorized` when its server-resolved grant lacks `assess:matches`.

## Still intentionally deferred

- persistence and secret verification for agent credentials
- concrete Workspace/ActionPolicy-to-credential-grant composition
- MCP authentication middleware that establishes the trusted principal and credential reference
- capability administration UI/API
- stricter identity-resolution capabilities

These can be added behind the existing credential-source and authentication boundaries without changing the versioned read or command contracts.
