# Ownership model

LMX distinguishes semantic ownership from repository review routing.

## Domain/package ownership

Domain ownership answers questions such as:

- Which bounded context owns this concept?
- Which package may change its invariants?
- Which package exposes the public application API?
- Which team is accountable for incidents, maintenance, and architectural decisions?

This is richer than file ownership. A package may own a business concept even when supporting files also exist in migrations, tests, documentation, analytics projections, or integration adapters.

The machine-readable registry is `config/ownership.yml`.

## GitHub CODEOWNERS

`.github/CODEOWNERS` is the GitHub review-routing projection of ownership. It maps repository paths to GitHub users or teams so pull requests can automatically request the right reviewers and branch protection can require owner review.

CODEOWNERS is intentionally not the canonical domain model because it cannot express bounded-context semantics, public contracts, incident routing, Slack channels, Backstage entities, dependency direction, or ownership of concepts that span multiple file locations.

LMX should therefore treat CODEOWNERS as an operational projection of the richer ownership registry. While the project has one owner, both files can be maintained manually. If the team grows, CODEOWNERS should be generated or validated from `config/ownership.yml` to avoid drift.

## Backstage and notification routing

The same logical owner IDs can later be mapped to Backstage `Group`/`User` ownership, service or component catalog metadata, Slack channels, incident escalation, dashboards, and repository notifications.

Conceptually:

```text
config/ownership.yml
        |
        +--> .github/CODEOWNERS      # PR review routing
        +--> Backstage owner         # catalog/accountability
        +--> Slack channel mapping   # notifications
        +--> incident ownership      # operations
        +--> agent work allocation   # coding sessions
```

The source of truth is the logical ownership identifier, not a Slack channel name or GitHub team handle.

## Ownership versus permissions

Ownership means accountability, not exclusive permission to edit. Another package or worker may propose a change, but changes to owned invariants or public contracts should be reviewed by the owner.

For agent parallelism, ownership is also a contention boundary: a session gets one primary package and should avoid editing other packages unless the task explicitly changes a contract.

## Shared/integration ownership

Some files do not belong to a business bounded context. They are integration-owned and are intentionally serialized during parallel work. Examples include global dependency lockfiles, CI, Rails boot configuration, global routes, shared RLS primitives, and `db/structure.sql`.

See `spec/development/parallel-development.md` for the merge and worktree rules.
