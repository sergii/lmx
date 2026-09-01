# Application adoption

LMX reuses the existing Rails/PostgreSQL/Inertia donor application instead of bootstrapping a third repository or a fresh Rails app.

## Repositories

- `sergii/lmx` is the canonical product repository and long-term system of record for specification, configuration, roadmap, and application code.
- `sergii/a322043jkf844f93mrfff` is the donor repository.
- donor `main` is frozen as the original snapshot.
- donor branch `lmx/adoption` is the temporary cleanup/adaptation branch.

The target layout is:

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

No third repository is required now.

## Why cleanup happens on the donor branch first

The GitHub application connector can safely modify the donor in place while preserving donor `main`. Cross-repository Git object copying is not a reliable application-migration mechanism, so cleanup/adaptation happens on `lmx/adoption` first.

When the adoption branch reaches a coherent baseline, it is imported into `sergii/lmx/application/` as a squashed subtree snapshot. From that point forward, application development happens only in `sergii/lmx/application/`; the donor repository becomes archival.

A local import can use:

```bash
git subtree add \
  --prefix=application \
  git@github.com:sergii/a322043jkf844f93mrfff.git \
  lmx/adoption \
  --squash
```

After import, the donor branch is not a second source of truth.

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
