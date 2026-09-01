# Donor application audit

Donor: `sergii/a322043jkf844f93mrfff`

Adoption workbench: donor branch `lmx/adoption`.

## Keep

These foundations are useful to LMX and should survive adoption with only naming/configuration cleanup:

- Rails 8.1 / Ruby 4 baseline
- PostgreSQL
- UUIDv7 primary keys
- TypeID public identifiers
- Inertia + React + TypeScript
- Tailwind CSS
- Radix-backed `components/ui/*` source
- authentication/session/email-verification/password-reset flow
- Organization/Workspace tenant boundary
- PostgreSQL RLS and `structure.sql`
- Action Policy
- Solid Queue / Solid Cache / Solid Cable
- RSpec and direct RLS boundary tests
- Brakeman / bundler-audit / RuboCop / JS lint/typecheck CI concepts
- Docker/Kamal deployment foundation

## Keep as a design pattern, redesign as LMX domain

- `Candidate` - remains a first-class LMX entity; a User can be linked to a Candidate but candidates do not need user accounts
- pipeline/Kanban interaction machinery - reuse frontend interaction patterns, replace staffing card semantics
- `SourcingBrief` - salvage as SearchProfile/OpportunityProfile ideas
- `Evidence` - preserve the evidence-first pattern and confidence/provenance semantics
- AI/manual/final assessment separation - reuse for derived LMX interpretation
- `Interview`, transcripts, notes, recordings and assessment patterns - reuse for Personal CRM / InterviewPrep loop
- `ApplicationStageEvent` idea - evolve toward domain events / projections
- append-only `AuditEvent` intuition - replace with Event Store + audit projection

## Replace

- old `Job` -> LMX `JobOpening`
- old recruiter-owned `JobPosting` -> observed market `JobPosting`
- one-candidate/one-job application uniqueness -> repeatable `Application` attempts
- mutable posting `content_snapshot` as history -> RawPayload + SourceObservation + normalized snapshots
- implicit tenant `default_scope` -> explicit `WorkspaceContext.with(...)` + PostgreSQL RLS
- staffing `ClientCompany -> Project -> Job` as the semantic core -> Company + OpeningParty + JobOpening, with optional RecruitingEngagement for agency workflows

## Remove from the adopted baseline

- ReUI duplicate component stack
- Base UI-backed ReUI components
- Gantt demo/controller/routes/specs
- shadcn/ReUI registry configuration as a project dependency mechanism
- staffing-specific client portal as a core LMX module
- obsolete demo screens and unused product-specific artifacts as they are identified

## Defer, do not lose

These may be useful after the personal LMX loop works and should not be deleted before their useful behavior is mapped:

- meetings
- tasks / next-action concepts
- client decisions
- recruiter/team workflow ideas
- recruiting/client presentation patterns

They can return through the Personal CRM or optional Recruiting bounded contexts instead of controlling Market Catalog semantics.

## Portability debt to remove before subtree import

- machine-local `enforceable` Gem path and associated donor-only test wiring
- `ReactStarterKit`, `react_starter_kit`, and `hire_do*` legacy names
- unused JS dependencies left after ReUI/Gantt removal
- deployment placeholders that still describe the donor

## Adoption status

Started on 2026-09-01.

Completed on `lmx/adoption` so far:

- removed ReUI/Gantt source surface and Gantt route/navigation
- removed `components.json` registry configuration
- introduced explicit `WorkspaceContext.with(...)`
- removed `OrganizationScoped` default scope while retaining automatic organization assignment and DB RLS boundary
- moved request tenant setup through `WorkspaceContext`
- renamed the Rails application module to `Lmx`
- created initial modular-monolith package skeleton for Workspace, Acquisition, Market Catalog, Talent Profile, Intelligence, Personal CRM, Recruiting, Delivery and Integration

The donor `main` branch remains unchanged.
