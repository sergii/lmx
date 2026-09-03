# LMX application

This directory contains the canonical Rails/PostgreSQL/Inertia application for LMX.

Product semantics, bounded contexts, architecture, events, interfaces, ownership, and development rules live in the repository root under `../spec/` and `../config/`.

## Working directory

When the repository is checked out at its root, run application commands from this directory:

```bash
cd application
```

## Local setup

Start PostgreSQL and prepare the application:

```bash
docker compose up -d db
bin/setup
```

The schema is stored in `db/structure.sql` because PostgreSQL RLS policies are part of the application security boundary.

## Verification

Run the relevant checks before handoff:

```bash
bin/rails lmx:config:validate
bin/packwerk validate
bin/packwerk check
bin/rubocop
bin/rspec
npm ci
npm run lint
npm run format
npm run check
```

Operational Phase 0 readiness is checked with:

```bash
bin/rails lmx:phase0:check
```

That command is read-only and is intended to be run against a configured staging or production environment after deployment.

## Canonical provenance

The initial canonical application snapshot was imported from:

- repository: `sergii/a322043jkf844f93mrfff`
- branch: `lmx/adoption`
- commit: `0cb0ba29535b0f5d77f543f24d386feb948f8f02`

The donor repository is archival after this import. New application development happens only in `sergii/lmx`.
