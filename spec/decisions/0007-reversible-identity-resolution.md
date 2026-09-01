# ADR 0007: Identity resolution must be explainable and reversible

Status: Accepted

## Context

The same hiring need can appear under different titles and URLs across several sources. Deterministic matching is insufficient in some cases, while semantic/LLM matching can make mistakes. Incorrect merges would corrupt lifecycle, salary, company and application analytics.

## Decision

Represent identity resolution as versioned `ResolutionDecision` records with confidence and evidence.

Linking a JobPosting to a JobOpening and merging canonical openings must be reversible. Support explicit unlink/relink and merge-revert operations without deleting historical observations.

Resolver metadata should include algorithm/rules/model version, confidence, deterministic evidence, semantic evidence, timestamp, and actor/executor when applicable.

## Consequences

- deduplication remains auditable
- resolver quality can be measured over time
- LLM-assisted matching is safe to correct
- incorrect merges do not permanently destroy source history
- projections may need repair/rebuild after an identity decision is reversed
