# Parallel development

LMX is intentionally structured so multiple humans and coding agents can work in parallel without sharing mutable implementation details.

The unit of parallel work is a bounded context or a narrowly scoped cross-cutting integration task. The default is one branch, one worktree, one issue, and one primary package per worker.

## Safe parallel lanes

The initial lanes are:

- Acquisition - SourceRun, RawPayload, IngestionRecord, SourceObservation, source adapters.
- Market Catalog - Company, OpeningParty, JobOpening, JobPosting, identity resolution, lifecycle.
- Talent Profile - Candidate, CandidateProfileVersion, skills, experience, preferences, evidence.
- Integration - API and MCP contracts, provenance envelopes, external processor adapters.

Intelligence should depend on stable Market Catalog and Talent Profile contracts. Personal CRM should depend on stable Candidate and JobOpening identities. Delivery can evolve independently once integration events are stable.

## Branch and worktree convention

Each concurrent worker uses a separate branch and worktree.

Examples:

```text
feat/acquisition-source-run
feat/market-catalog-core
feat/talent-profile-core
feat/mcp-read-contracts
```

Example worktrees:

```bash
git worktree add ../lmx-acquisition feat/acquisition-source-run
git worktree add ../lmx-market feat/market-catalog-core
git worktree add ../lmx-talent feat/talent-profile-core
git worktree add ../lmx-mcp feat/mcp-read-contracts
```

A branch should not become a second long-lived source of truth. Merge small coherent slices frequently.

## Package ownership rule

A worker may freely change files owned by the package assigned to the task. Cross-package changes require an explicit contract reason and should be called out in the PR.

Packages communicate through explicit public application services, commands, queries, immutable events, or deliberately shared value objects. Do not reach into another package's private Active Record models as a shortcut.

Packwerk is a mechanical dependency guardrail. It does not replace DDD ownership or design review.

## Shared files are serialized

The following files and areas are integration-owned and should not be edited concurrently unless the workers explicitly coordinate:

- `Gemfile` and `Gemfile.lock`
- `package.json` and lockfiles
- Rails application and environment configuration
- global routes
- shared RLS infrastructure
- root-level shared concerns and technical primitives
- CI workflows
- `db/structure.sql`
- global schema or migration repair work
- repository-wide UI theme/tokens

A package may add its own migration, but changes to a shared migration, migration ordering repair, or generated `db/structure.sql` are serialized at integration time.

## Migration rule

Every migration belongs conceptually to one package even though Rails keeps migrations in one global sequence.

Migration names should make ownership obvious, for example:

```text
CreateAcquisitionSourceRuns
CreateMarketCatalogJobOpenings
CreateTalentProfileCandidateProfileVersions
```

Do not edit another lane's migration after it has been shared. Add a new migration instead.

## Agent session contract

Before changing code, a ChatGPT, Codex, or other coding-agent session should:

1. Read `spec/README.md`.
2. Read `spec/domain.md`, `spec/bounded-contexts.md`, and `spec/architecture.md` as needed for the task.
3. Read this file and `spec/development/ownership.md`.
4. Read the target package README and `package.yml`.
5. Identify the issue, branch, and package it owns.
6. Avoid unrelated cleanup.
7. Run package-boundary checks and relevant tests before handing work off.

The repository should contain enough context that a new agent does not need the historical chat transcript to work safely.

## Current donor-adoption exception

Until the Rails application is imported into `sergii/lmx/application/`, application implementation work happens in the donor repository `sergii/a322043jkf844f93mrfff` using `lmx/adoption` as the temporary integration branch. Donor `main` remains frozen.

Concurrent implementation branches should branch from `lmx/adoption` and merge back into `lmx/adoption`, not into donor `main`. After the squashed subtree import, this exception disappears and `sergii/lmx` becomes the only development source of truth.
