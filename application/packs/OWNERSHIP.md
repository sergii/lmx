# Package ownership during LMX adoption

These package boundaries are both DDD ownership boundaries and safe parallel-development lanes.

## platform

Owns shared technical Rails primitives only: `ApplicationRecord`, typed-ID infrastructure, and similar non-business foundations.

Does not own business concepts. Changes here are high fan-out and should be coordinated.

## workspace

Owns workspace identity, users, memberships, tenant execution context, and workspace authorization boundary.

Public boundary should expose workspace execution/context behavior without requiring other packages to reproduce RLS or membership rules.

## acquisition

Owns source acquisition, source runs, raw payloads, ingestion records, source observations, and source-specific adapters.

Does not own Company, JobOpening, Candidate, Application, or matching decisions.

Public outputs are immutable observations/evidence and explicit acquisition application services.

## market_catalog

Owns Company, OpeningParty, JobOpening, JobPosting, identity resolution, market lifecycle, presence/absence interpretation, and reversible resolution decisions.

Consumes acquisition evidence through explicit contracts. Does not own candidate fit or personal application state.

## talent_profile

Owns Candidate, CandidateProfileVersion, experience, skills, preferences, candidate evidence, and candidate-side assessments.

Does not own market vacancy state or application workflow.

## intelligence

Owns versioned MatchAssessment, Opportunity Score, Action Priority, derived interpretations, and comparison of processor/model outputs.

Consumes stable Market Catalog and Talent Profile contracts. It must not silently rewrite source evidence or candidate history.

## personal_crm

Owns Application, stage progression, contacts, interactions, interviews, interview preparation lifecycle, next actions, and outcomes.

Personal state must not mutate market lifecycle merely because a candidate was rejected or withdrew.

## recruiting

Owns optional third-party/client recruiting workflows such as RecruitingEngagement, candidate presentations, client decisions, and assignment/account ownership.

It may reference shared JobOpening and Candidate identities but must not redefine them.

## delivery

Owns Telegram and other notification delivery policies, delivery attempts, status, and channel-specific formatting.

Consumes integration/domain events rather than scraping domain tables ad hoc.

## integration

Owns API, MCP, webhook and external-agent adapters, provenance envelopes, credentials/capabilities, Inbox/Outbox-facing adapters, and external processor invocation boundaries.

External agents never receive permission to bypass application/domain rules and mutate another package's private persistence directly.

## Cross-package rule

A package may depend on another package only through a deliberate public contract. Packwerk mechanically checks declared dependencies; architectural review determines whether the dependency direction is semantically correct.

If a task seems to require edits in three or more business packages, stop and first decide whether the change belongs in an explicit contract, integration event, shared technical primitive, or separate orchestration layer.
