# ADR 0011 - Separate personal opportunity disposition from application attempts

## Status

Accepted.

## Context

A canonical JobOpening is market state. A Candidate may personally save it, ignore it, or later apply to it. Those handling decisions are not themselves application attempts, and the same Candidate may legitimately apply to the same JobOpening again later.

Collapsing Save / Ignore / Apply into one mutable Application row would recreate the donor staffing constraint that canonical LMX explicitly rejects. It would also make it impossible to distinguish "I do not want to act on this opening" from "I submitted an application" without inventing fake application records.

## Decision

Personal CRM owns two separate concepts:

- `OpportunityDisposition` is the current candidate-opening personal handling projection. Initial states are `saved`, `ignored`, and `applied`.
- `Application` is one concrete application attempt, optionally via a specific JobPosting. Attempts are numbered per candidate-opening pair and the schema permits multiple attempts.

Save and Ignore only change `OpportunityDisposition`. They never create an Application.

The initial web Apply action records attempt 1 idempotently and moves the disposition to `applied`. Once an application has been recorded, Save or Ignore cannot erase that fact by moving the projection backwards. A future explicit reapply command may create attempt 2 or later.

Disposition changes and application creation append immutable Personal CRM domain events with command provenance. The tables are workspace-scoped and protected by PostgreSQL RLS.

## Consequences

The UI can expose lightweight triage without polluting application history. Application analytics count actual attempts rather than bookmarks or rejections. Personal workflow remains independent of JobOpening lifecycle, while repeat applications remain representable without changing the core model.
