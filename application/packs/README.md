# LMX packages

LMX is a domain-driven modular monolith. Each directory under `packs/` is a bounded-context ownership boundary and a preferred parallel-development lane.

Packwerk is enabled as a dependency-boundary guardrail. Packwerk 3.3 core checks dependencies; it does not provide privacy checking. Public APIs are therefore kept narrow by package structure and conventions, while dependency declarations are mechanically checked in CI.

The repository root is intentionally a non-strict legacy package during adoption. New domain code goes into strict packages and must declare every cross-package dependency explicitly.

Read `OWNERSHIP.md` for the semantic ownership of each package and `../AGENTS.md` before concurrent agent work.

Initial packages:

- `platform` - shared technical Rails primitives with no business ownership, such as `ApplicationRecord` and typed IDs
- `workspace` - workspace identity, users, memberships, tenant execution context
- `acquisition` - sources, adapters, raw payloads, ingestion records, source observations
- `market_catalog` - companies, opening parties, job openings/postings, identity resolution, lifecycle
- `talent_profile` - candidates, profile versions, experience, skills, evidence
- `intelligence` - match assessments, ranking, derived interpretation
- `personal_crm` - applications, contacts, interactions, interviews, next actions
- `recruiting` - optional client recruiting/engagement workflows
- `delivery` - Telegram and other notification delivery policies
- `integration` - API, MCP, webhook, agent credentials and external processor adapters

Cross-package access should move through explicit public application APIs, commands/queries, or versioned events instead of arbitrary private model references.
