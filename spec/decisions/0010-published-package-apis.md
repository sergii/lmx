# ADR 0010 - Published package APIs and private implementation boundaries

## Status

Accepted.

## Context

ADR 0008 establishes LMX as a domain-driven modular monolith with Packwerk-enforced package boundaries and narrow public application interfaces. The implementation now contains real bounded-context packages such as Market Catalog, Talent Profile, Acquisition, Integration, Intelligence, Workspace, Personal CRM, Recruiting, and Delivery.

Without an explicit published-interface rule, a declared package dependency can still become accidental permission to couple to another context's ActiveRecord models, repositories, service objects, or internal orchestration. That would make refactoring unsafe, blur bounded-context ownership, and recreate an unconstrained monolith behind Packwerk dependency declarations.

LMX also needs a stable distinction similar to service-oriented systems: consumers should know which operations are supported contracts and which classes are free to change without coordination.

## Decision

Each bounded-context package has a **published application interface** and a **private implementation**.

For Rails packages, the canonical published-code location is:

```text
packs/<package>/app/public/<namespace>/...
```

Packwerk privacy enforcement must treat constants under `app/public` as callable by other packages and constants outside `app/public` as package-private.

### Cross-context rule

Code in one bounded context MUST NOT reference another bounded context's private models, repositories, application services, jobs, or persistence helpers.

Synchronous cross-context calls MUST enter through the owning context's published application interface, for example:

```ruby
MarketCatalog::Api.search_openings(...)
MarketCatalog::Api.fetch_opening(...)
TalentProfile::Api.fetch_candidate(...)
```

Asynchronous cross-context communication should use versioned domain/integration events where that better matches the business boundary.

A caller must declare a Packwerk dependency on the package whose public API it consumes. A dependency declaration is not permission to call private constants.

### Public API shape

Published APIs should expose business/application capabilities, not persistence mechanics.

Prefer semantic operations such as:

```ruby
MarketCatalog::Api.fetch_opening(opening_id:)
Workspace::Api.with_workspace(workspace_id:, principal:) { ... }
```

over exposing ActiveRecord relations or private implementation objects.

Public interfaces should return stable snapshots/value objects/contracts rather than leaking mutable ActiveRecord records across bounded contexts.

Public identifiers crossing a package boundary should remain opaque to callers unless the owning package explicitly publishes parsing semantics.

### Internal implementation

Implementation classes remain private to their package even if their names are convenient to call directly.

Examples include:

- ActiveRecord models
- repositories and query objects
- command/service objects such as `SearchOpenings.call(...)`
- persistence adapters
- internal policy/orchestration helpers
- background jobs owned by the package

The `.call` convention is an implementation idiom, not an architectural boundary and not a public contract by itself.

Repository pattern abstractions may be used inside a package when they provide useful persistence isolation, testing seams, or dependency inversion. Repositories are not required globally and are private unless deliberately published.

### Refactoring contract

Code outside a package may depend on its published interface and versioned events only.

Therefore:

- public API changes require compatibility review and coordination with consumers
- private classes may be renamed, split, replaced, or rewritten without cross-package coordination
- changing ActiveRecord schema or internal service composition does not require consumers to change when the published contract is preserved
- a Packwerk privacy violation is an architecture failure, not something to suppress mechanically

When a privacy violation appears, resolve it in this order:

1. determine which bounded context owns the capability
2. use an existing published interface if one exists
3. add a narrow published operation if the capability is legitimately cross-context
4. move the behavior if ownership was wrong
5. only then declare the required package dependency

Do not move private constants into `app/public` merely to make Packwerk green.

## Relationship to service-oriented architecture

LMX is not a network-distributed SOA system. It is one deployable modular monolith with one primary process and transaction boundary.

However, bounded contexts use **service-oriented discipline inside the monolith**: explicit capabilities, published contracts, private implementations, and controlled dependencies. These boundaries are intended to make ownership clear and make future service extraction possible without designing the system around distributed services prematurely.

## Relationship to application architecture patterns

This decision composes established patterns rather than defining a new architecture style:

- **Domain-Driven Design** supplies bounded contexts and explicit model ownership
- **Modular Monolith** keeps those contexts in one deployable application
- **Packwerk** provides static dependency and privacy enforcement
- **Service Layer / Published Interface** defines stable application capabilities exposed by a context
- **Ports and Adapters** isolates protocol/infrastructure adapters such as MCP from application/domain behavior
- **Command Query Separation** distinguishes state-changing operations from read operations
- **Repository** remains an optional internal persistence abstraction where useful

## Enforcement

The Rails implementation should progressively enable both:

```yaml
enforce_dependencies: strict
enforce_privacy: true
```

for bounded-context packages.

CI must continue to run:

```text
bin/packwerk validate
bin/packwerk check
```

Privacy enforcement should be introduced incrementally if existing donor coupling prevents an all-at-once transition. New LMX package code must not introduce new private cross-package references.

## Consequences

Positive:

- public versus internal code is mechanically visible and enforceable
- bounded contexts can refactor implementation safely
- package dependencies describe real architectural relationships rather than arbitrary constant access
- APIs are reusable by web, HTTP, MCP, CLI, jobs, and agents without duplicating domain logic
- later extraction to separately deployed services remains possible when justified

Costs:

- some convenient cross-model ActiveRecord associations/calls are forbidden
- public APIs require deliberate contract design
- legacy donor coupling may require staged cleanup before privacy can be enabled everywhere
- published interfaces become compatibility surfaces that must be maintained intentionally
