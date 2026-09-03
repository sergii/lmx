# LMX coding agent instructions

This repository is the canonical specification and application repository for LMX.

## Before changing code

Read the minimum relevant context from the repository itself. Do not rely on chat history as the source of truth.

Start with:

- `spec/README.md`
- `spec/domain.md`
- `spec/bounded-contexts.md`
- `spec/architecture.md`
- `spec/development/parallel-development.md`
- `spec/development/ownership.md`
- `config/ownership.yml`

Then read the target package README and `package.yml` under `application/`.

## Work boundary

Every implementation task must identify:

- one issue or explicit task
- one branch
- one worktree when other work is concurrent
- one primary package or one explicit cross-cutting integration scope

Do not perform unrelated cleanup. Do not edit another package's private implementation to make the current task easier.

Cross-package communication must use explicit public application services, commands, queries, versioned events, or deliberately shared value objects. Packwerk dependency checks must remain green.

## Parallel work

Follow `spec/development/parallel-development.md`.

Shared files such as dependency lockfiles, global Rails configuration, routes, CI, shared RLS infrastructure, and `application/db/structure.sql` are integration-owned and should be changed serially when multiple workers are active.

## Ownership

`config/ownership.yml` is the semantic ownership registry. `.github/CODEOWNERS` is GitHub review routing, not the domain source of truth.

A worker may propose changes outside its owned package only when the task explicitly requires a contract change. Call that out in the PR.

## Domain rules

- LMX is the system of record; external agents are replaceable processors.
- Source observations are immutable evidence, not automatic domain mutations.
- Market state and personal application state are separate.
- Identity-resolution decisions must remain explainable and reversible.
- External actors do not mutate domain tables directly; writes go through application/domain boundaries.
- Preserve provenance for agent-produced analysis and derived interpretations.

## Repository rules

The root `README.md` must remain exactly:

```text
LMX
```

Do not add product explanation to the root README.

## Canonical application

The Rails application lives under `application/`. All new LMX implementation work happens in this repository.

The historical donor `sergii/a322043jkf844f93mrfff` is archival after the canonical snapshot import. Do not continue implementation on donor `lmx/adoption` and do not merge LMX work into donor `main`.

Run Rails, Bundler, Packwerk, npm, and application tests from `application/` unless a root-level command explicitly wraps them.
