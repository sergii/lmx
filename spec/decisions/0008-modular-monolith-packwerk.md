# ADR 0008 - Modular monolith with enforced package boundaries

## Status

Accepted.

## Context

LMX spans several distinct domains: acquisition, canonical market identity, candidate knowledge, matching/intelligence, application/interview workflow, delivery, integrations, and potentially recruiting for clients.

Splitting these concerns into separately deployed services now would add operational complexity, distributed transactions, event-contract overhead, deployment coordination, and debugging cost before there is evidence that independent deployment is required.

At the same time, keeping everything as an unconstrained Rails application would make it easy for ActiveRecord associations, services, controllers, and jobs to create arbitrary cross-domain coupling. That would make later extraction expensive and blur the ontology.

The existing donor application already provides a strong Rails/PostgreSQL/Inertia foundation and PostgreSQL RLS tenant boundary.

## Decision

LMX will begin as a domain-driven modular monolith.

Major bounded contexts map to explicit application packages, initially including:

- Workspace / Identity foundation
- Acquisition
- Market Catalog
- Talent Profile
- Intelligence
- Personal CRM
- optional Recruiting
- Delivery
- Integration

Packwerk should be used to enforce dependency and privacy boundaries in CI when compatible with the selected Rails/Ruby baseline. If Packwerk itself becomes incompatible or insufficient, replace the enforcement tool without abandoning the package architecture.

Packages expose narrow public application interfaces. Cross-context communication should prefer explicit commands, queries, public package APIs, and versioned events rather than direct access to private models/services.

A likely physical layout is:

```text
application/
  packs/
    workspace/
    acquisition/
    market_catalog/
    talent_profile/
    intelligence/
    personal_crm/
    recruiting/
    delivery/
    integration/
```

The exact directory layout may evolve without changing this decision.

Tenant execution outside ordinary requests must use an explicit boundary such as `WorkspaceContext.with(...)`. PostgreSQL RLS remains a defense-in-depth/security boundary, while application behavior should not depend on a pervasive implicit ActiveRecord `default_scope`.

## Consequences

Positive:

- one deployable application and one primary transaction boundary
- simple local development and operations
- explicit DDD boundaries
- dependency violations caught before merge
- easier reasoning about ownership
- easier future service extraction when justified
- donor application infrastructure can be reused without adopting its staffing-domain coupling

Costs:

- package boundaries require discipline and CI enforcement
- some Rails conventions/associations become less convenient across contexts
- public APIs and events require more deliberate design than direct model references
- Packwerk configuration introduces maintenance overhead

## Extraction rule

A package should become a separately deployed service only when there is concrete pressure such as:

- independently scaling workload
- materially different availability/latency requirements
- independent team ownership
- security/isolation needs
- deployment cadence conflicts
- a transaction boundary that is already naturally asynchronous

Service extraction is an optimization, not the starting architecture.