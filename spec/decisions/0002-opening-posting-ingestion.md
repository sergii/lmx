# ADR 0002: Separate opening, posting, and ingestion

Status: Accepted

## Context

The same underlying hiring need may be published on several websites at different times and may arrive in LMX through several technical paths.

Treating every URL as a vacancy destroys cross-source history. Treating the ingestion transport as the source also loses provenance.

## Decision

Model three distinct concepts:

- JobOpening: canonical hiring need.
- JobPosting: concrete publication on an external source.
- IngestionRecord: how LMX received an observation.

Preserve PostingSnapshots and raw payload references when practical.

## Consequences

LMX can analyze cross-source publication, reposts, reopenings, source lead time, and parser provenance while keeping one canonical opportunity for the personal workflow.
