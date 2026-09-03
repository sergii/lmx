# LMX donor adoption agent instructions

This repository is a temporary application-adoption workbench. Donor `main` is frozen. All LMX implementation work here is based on `lmx/adoption` and will later be imported as a squashed snapshot into `sergii/lmx/application/`.

## Before changing code

Read:

- `packs/README.md`
- `packs/OWNERSHIP.md`
- the target package `package.yml`
- relevant tests and public application services

The canonical LMX architecture and domain specification live in `sergii/lmx/spec/`.

## Concurrent work

Do not have multiple agents commit directly to `lmx/adoption` at the same time. Each concurrent worker branches from the latest `lmx/adoption` commit.

Examples:

```text
feat/acquisition-source-run
feat/market-catalog-core
feat/talent-profile-core
feat/mcp-read-contracts
```

Each worker should use a separate git worktree and one primary package.

Merge small coherent branches back into `lmx/adoption`. Never merge LMX adoption work into donor `main`.

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
- `.github/workflows/**`
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
