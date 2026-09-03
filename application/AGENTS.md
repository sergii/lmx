# LMX application coding agent instructions

This directory contains the canonical Rails application for LMX. The product/domain specification lives in the repository root under `../spec/`, and machine-readable ownership lives in `../config/ownership.yml`.

## Before changing code

Read the minimum relevant canonical context from the repository root:

- `../spec/README.md`
- `../spec/domain.md`
- `../spec/bounded-contexts.md`
- `../spec/architecture.md`
- `../spec/development/parallel-development.md`
- `../spec/development/ownership.md`
- `../config/ownership.yml`

Then read:

- `packs/README.md`
- `packs/OWNERSHIP.md`
- the target package `package.yml`
- relevant tests and public application services

## Concurrent work

Use one branch and one worktree per concurrent worker, based on the latest canonical `sergii/lmx` integration state. Keep one primary package or one explicit cross-cutting integration scope per task.

Examples:

```text
feat/acquisition-source-run
feat/market-catalog-core
feat/talent-profile-core
feat/mcp-read-contracts
```

Merge small coherent slices back into the canonical repository. The historical donor repository is archival and is not a development target.

## Package boundary

New domain code belongs under `packs/<context>/`. Do not add new business-domain code to the legacy root package.

Do not directly mutate or depend on another package's private Active Record models. Cross-package behavior should use explicit public application services, commands, queries, events, or deliberate shared technical primitives.

Run:

```bash
bin/packwerk validate
bin/packwerk check
```

and the relevant test suite before handoff.

## Serialized shared files

Coordinate before editing these while another lane is active:

- `Gemfile` / `Gemfile.lock`
- `package.json` / lockfile
- `config/application.rb`
- `config/routes.rb`
- root `.github/workflows/**`
- shared RLS infrastructure
- `db/structure.sql`
- repository-wide UI theme/tokens

Package-specific migrations may be authored in parallel, but migration repair and the final generated SQL structure are integration work.

## Current safe lanes

- `packs/acquisition` - can run independently.
- `packs/market_catalog` - can run independently against the SourceObservation contract.
- `packs/talent_profile` - can run independently.
- `packs/integration` - contract-first MCP/API work can run independently.

Delay deep `intelligence` work until Market Catalog and Talent Profile contracts stabilize. Delay deep `personal_crm` refactoring until Candidate and JobOpening identities stabilize.
