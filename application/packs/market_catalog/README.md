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

## Lifecycle reconciliation

Evidence capture and canonical lifecycle mutation are separate operations.

`MarketCatalog::ReconcilePostingLifecycle` recomputes the current posting state from immutable posting snapshots. It is deliberately replay-safe and conservative:

- `unknown` evidence does not change canonical lifecycle;
- one or more current `missing` observations produce `missing`, not `closed`;
- `explicit_closed` evidence closes the posting even if later observations in the same absence run are merely `missing`;
- a newer confirmed `present` observation clears absence state;
- the first confirmed presence after an absence projects `reappeared`, while a later continuous presence returns to `present`;
- out-of-order older absence evidence cannot override a newer confirmed presence already recorded on the posting.

Reconciliation cascades to the linked `JobOpening`. An opening stays `open` while any linked posting is currently present, becomes `closed` only when all linked postings are closed, and otherwise remains conservatively `missing` or `probably_closed`. Reappearance on any linked posting can project the opening as `reopened`.

Posting-to-opening link, relink, and unlink operations also recompute the affected opening projections. The reconciliation services are deterministic projections over retained evidence, so they can safely be rerun after replay, repair, or parser improvements.

## Legacy donor boundary

The root donor classes `Job`, `JobPosting`, `ClientCompany`, and `Project` implement the old staffing workflow. They are not the canonical LMX market model. During adoption they remain available to legacy screens while new LMX code uses the namespaced Market Catalog models and `market_catalog_*` tables.

## Public application API

Cross-context callers should use `MarketCatalog::Api`. The API returns immutable hashes with typed identifiers rather than leaking Market Catalog Active Record models.

Initial mutation capabilities are:

- `create_company`
- `create_opening`
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
