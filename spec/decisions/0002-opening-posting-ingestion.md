# ADR 0002: Separate opening, posting, observation, and ingestion

Status: Accepted

## Context

The same underlying hiring need may be published on several websites at different times and may arrive in LMX through several technical paths.

Treating every URL as a vacancy destroys cross-source history. Treating the ingestion transport as the source loses provenance. Treating a parser result as canonical state also makes source/parsing errors indistinguishable from business facts.

## Decision

Model distinct concepts:

- JobOpening: canonical hiring need.
- JobPosting: concrete publication on an external source.
- SourceObservation: immutable evidence of what a source showed at a point in time.
- IngestionRecord: how LMX received the evidence.

Preserve PostingSnapshots and raw payload references when practical.

## Consequences

LMX can analyze cross-source publication, reposts, reopenings, source lead time, observation time, and parser provenance while keeping one canonical opportunity for the personal workflow.

Acquisition/parsing remains evidence-producing rather than a hidden writer of canonical market state.
