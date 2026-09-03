# Donor application audit

Donor: `sergii/a322043jkf844f93mrfff`

Historical adoption workbench: donor branch `lmx/adoption`.

## Keep

These foundations are useful to LMX and survived adoption with only naming/configuration cleanup:

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
- pipeline/Kanban/list/table interaction machinery - reuse frontend interaction patterns, replace staffing card semantics and persistence
- `SourcingBrief` - salvage as SearchProfile/OpportunityProfile ideas
- `Evidence` - preserve the evidence-first pattern and confidence/provenance semantics
- AI/manual/final assessment separation - reuse for derived LMX interpretation
- `Interview`, transcripts, notes, recordings and assessment patterns - reuse for Personal CRM / InterviewPrep loop
- `ApplicationStageEvent` idea - realized as immutable Personal CRM domain events plus rebuildable projections
- append-only `AuditEvent` intuition - replaced by Event Store + audit projections

## Replace

- old `Job` -> LMX `JobOpening`
- old recruiter-owned `JobPosting` -> observed market `JobPosting`
- one-candidate/one-job application uniqueness -> repeatable `Application` attempts
- mutable posting `content_snapshot` as history -> RawPayload + SourceObservation + normalized snapshots
- implicit tenant `default_scope` -> explicit `WorkspaceContext.with(...)` + PostgreSQL RLS
- staffing `ClientCompany -> Project -> Job` as the semantic core -> Company + OpeningParty + JobOpening, with optional RecruitingEngagement for agency workflows
- donor root-shell `PipelineController` / `ApplicationsController` direct ActiveRecord access -> composition over published Personal CRM and Market Catalog APIs

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

## Historical portability debt resolved during adoption

The adoption workbench removed or isolated:

- machine-local `enforceable` Gem path and associated donor-only test wiring
- `ReactStarterKit`, `react_starter_kit`, and `hire_do*` legacy names
- unused JS dependencies left after ReUI/Gantt removal
- deployment placeholders that described the donor

## Adoption status

Adoption started on 2026-09-01 and is complete.

The canonical snapshot from donor `lmx/adoption` was imported into `sergii/lmx/application/`. The donor `main` branch remains the frozen original snapshot, and the donor adoption branch is archival.

The canonical application now includes explicit `WorkspaceContext.with(...)`, PostgreSQL RLS, the `Lmx` application module, Packwerk package boundaries, canonical Market Catalog/Talent Profile/Intelligence foundations, and Personal CRM opening/application workflow based on transactional commands and immutable domain events.

Future implementation work happens only in `sergii/lmx`. Donor UI code may still be consulted as a design reference, but donor domain models and controllers are not an implementation authority.
