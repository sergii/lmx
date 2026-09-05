# Market Catalog

Market Catalog owns LMX's canonical interpretation of the hiring market.

This package owns:

- `MarketCatalog::Company`
- `MarketCatalog::JobOpening`
- `MarketCatalog::JobPosting`
- `MarketCatalog::PostingSnapshot`
- `MarketCatalog::OpeningParty`
- `MarketCatalog::ResolutionDecision`
- posting identity and posting-to-opening resolution
- market lifecycle state once evidence has been interpreted

It does not own source retrieval, raw payloads, source runs, or `SourceObservation`; those belong to Acquisition. It does not own Candidate profiles, matching/ranking, Applications, recruiting engagements, or notification delivery.

## Global catalog boundary

The canonical market catalog is system-wide rather than workspace-scoped. A public market posting should not be duplicated once per workspace. Workspace-specific Candidates, Applications, preferences, and recruiting workflows may reference these canonical market entities through their own bounded-context APIs.

Private client-only recruiting data belongs in Recruiting, not in the global market catalog.

## Evidence boundary

`SourceObservation` remains owned by Acquisition. Market Catalog stores only its opaque observation identifier when creating a `PostingSnapshot`; there is intentionally no Active Record association across that package boundary.

A `PostingSnapshot` is an immutable normalized view of one source observation for one canonical `JobPosting`. It preserves normalized source facts and their evidence levels before later reconciliation changes market projections. A snapshot can carry `present`, `missing`, `explicit_closed`, or `unknown` source evidence without directly forcing the canonical posting lifecycle to the same state.

Repeated processing of the same source observation is idempotent when normalized content is identical. Different normalized output for the same observation is treated as a conflict rather than silently rewriting historical evidence.

A failed collector/source run is not absence evidence. Acquisition records failure separately; Market Catalog only advances an absence sequence when it receives an explicit immutable `missing` posting snapshot from accepted source evidence.

## Lifecycle reconciliation

Evidence capture and canonical lifecycle mutation are separate operations.

`MarketCatalog::ReconcilePostingLifecycle` recomputes the current posting state from immutable posting snapshots. It is deliberately replay-safe and conservative:

- `unknown` evidence does not change canonical lifecycle;
- one missing observation never manufactures closure;
- the default `v1` policy keeps the first two consecutive `missing` observations as `missing` and promotes the third to `probably_closed`;
- inferred `closed` from repeated absence is disabled by default; explicit `explicit_closed` evidence closes immediately;
- operators may explicitly configure an inferred-close threshold, which must be at least the `probably_closed` threshold;
- a newer confirmed `present` observation clears the absence sequence;
- the first confirmed presence after an absence projects `reappeared`, while a later continuous presence returns to `present`;
- out-of-order older absence evidence cannot override a newer confirmed presence already recorded on the posting.

The current projection records its policy snapshot under `JobPosting#metadata["lifecycle_projection"]`, including policy version, thresholds, consecutive missing observation count, and the latest evidence timestamp. This makes the current interpretation inspectable and allows a newer policy version to be introduced explicitly rather than silently changing semantics.

The default policy can be configured with:

```text
LMX_POSTING_LIFECYCLE_POLICY_VERSION=v1
LMX_POSTING_PROBABLY_CLOSED_AFTER_MISSES=3
LMX_POSTING_CLOSED_AFTER_MISSES=
```

An empty `LMX_POSTING_CLOSED_AFTER_MISSES` keeps inferred closure disabled. Setting it to an integer enables inferred closure only after that many consecutive missing observations. Both thresholds must be at least 2 and the closed threshold cannot be lower than the probably-closed threshold.

Reconciliation cascades to the linked `JobOpening`. An opening stays `open` while any linked posting is currently present, becomes `closed` only when all linked postings are closed, and otherwise remains conservatively `missing` or `probably_closed`. Reappearance on any linked posting can project the opening as `reopened`.

Posting-to-opening link, relink, and unlink operations also recompute the affected opening projections. The reconciliation services are deterministic projections over retained evidence, so they can safely be rerun after replay, repair, or parser improvements.

## Opening submission

`MarketCatalog::SubmitOpening` is the canonical mutation service for accepted opening submissions. It supports both URL-backed vacancies and no-URL opportunities, preserves the actual ingress interface, reuses stable canonical URL identity, and appends the resulting domain event/outbox message in the caller's transaction.

`MarketCatalog::Api.submit_opening` is intended for an already-established command boundary such as Integration MCP/API dispatch. The caller supplies trusted command provenance and owns Transactional Inbox idempotency.

`MarketCatalog::Api.submit_manual_opening` remains the browser/manual entry point. It owns its existing command receipt/idempotency wrapper and delegates canonical mutation to the same generic service with the fine-grained ingress label `web/manual`.

This distinction prevents MCP or future HTTP/API submissions from being mislabeled as manual web input while keeping one canonical identity-resolution path.

## Legacy donor boundary

The root donor classes `Job`, `JobPosting`, `ClientCompany`, and `Project` implement the old staffing workflow. They are not the canonical LMX market model. During adoption they remain available to legacy screens while new LMX code uses the namespaced Market Catalog models and `market_catalog_*` tables.

## Public application API

Cross-context callers should use `MarketCatalog::Api`. The API returns immutable hashes with typed identifiers rather than leaking Market Catalog Active Record models.

Initial mutation capabilities are:

- `create_company`
- `create_opening`
- `submit_opening`
- `submit_manual_opening`
- `record_posting`
- `record_posting_snapshot`
- `reconcile_posting_lifecycle`
- `resolve_posting_opening_link`

Initial read capabilities are:

- `fetch_company`
- `fetch_opening`
- `fetch_posting`
- `fetch_posting_snapshot`
- `fetch_posting_history`
- `search_openings`

Identity resolution follows the canonical deterministic evidence order: source external ID first, then canonical posting URL, then canonical application URL. Company plus title is never sufficient to merge postings or openings.

Resolution decisions are immutable. Re-linking or unlinking creates another `ResolutionDecision` rather than rewriting prior reasoning.
