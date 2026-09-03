# Application adoption

LMX reuses the existing Rails/PostgreSQL/Inertia donor application instead of bootstrapping a third repository or a fresh Rails app.

## Repositories

- `sergii/lmx` is the canonical product repository and long-term system of record for specification, configuration, roadmap, and application code.
- `sergii/a322043jkf844f93mrfff` is the historical donor repository.
- donor `main` is frozen as the original snapshot.
- donor branch `lmx/adoption` was the temporary cleanup/adaptation branch and is archival after import.

The canonical layout is:

```text
lmx/
  README.md
  config/
  spec/
  application/
    app/
    config/
    db/
    packs/
    Gemfile
    package.json
    ...
```

No third repository is required.

## Canonical import

The donor adoption baseline was imported into `sergii/lmx/application/` as a squashed snapshot from:

- repository: `sergii/a322043jkf844f93mrfff`
- branch: `lmx/adoption`
- donor commit: `0cb0ba29535b0f5d77f543f24d386feb948f8f02`

The imported application retains explicit provenance in `application/.lmx-donor.yml`.

From this point forward, application development happens only in `sergii/lmx/application/`; the donor repository is archival and is not a second source of truth.

The equivalent local import shape is:

```bash
git subtree add \
  --prefix=application \
  git@github.com:sergii/a322043jkf844f93mrfff.git \
  lmx/adoption \
  --squash
```

The actual canonicalization preserves the same semantic result: one reviewed canonical snapshot under `application/` with the exact donor SHA recorded as provenance.

## Adoption order

1. Remove duplicate/unused UI stacks and demos.
2. Introduce explicit `WorkspaceContext.with(...)`; retain PostgreSQL RLS and remove implicit tenant `default_scope` behavior.
3. Make the donor portable: remove machine-local dependencies and legacy naming.
4. Establish DDD modular-monolith packages and Packwerk boundary enforcement.
5. Preserve and redesign useful donor concepts: Candidate, pipeline interaction patterns, Evidence, Interview/Assessment, and SourcingBrief ideas.
6. Remove staffing-specific coupling from the semantic core (`ClientCompany -> Project -> Job`).
7. Introduce LMX canonical concepts: Company, OpeningParty, JobOpening, JobPosting, SourceObservation, CandidateProfileVersion, MatchAssessment, Application, InterviewPrep, and RecruitingEngagement as an optional context.
8. Import the coherent baseline under `lmx/application/`.
9. Continue the Phase 0 roadmap only from `sergii/lmx`.

Steps 1-8 are complete for the imported Phase 0 baseline. Step 9 is the active development mode.

## UI rule

The adopted application has one UI layer:

```text
Radix primitives
      +
LMX-owned React components
      +
LMX Tailwind tokens
```

ReUI/Base UI/Gantt demo code is removed. Existing `components/ui/*` source can be retained and normalized because it is owned source code, not a required shadcn runtime dependency.

## System-of-record rule

The application may delegate discovery, extraction, enrichment, and preliminary analysis to external agents. The accepted ontology, canonical identities, evidence history, CandidateProfileVersion, MatchAssessment versions, application/interview state, and domain events remain in LMX.
