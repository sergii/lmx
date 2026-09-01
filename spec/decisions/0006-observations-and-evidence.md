# ADR 0006: Observations are evidence, not direct domain mutations

Status: Accepted

## Context

External sources can be stale, inconsistent, temporarily unavailable, or parsed incorrectly. A crawler seeing a value or failing to see a posting must not automatically rewrite canonical market state.

## Decision

Introduce immutable `SourceObservation` records between acquisition and canonical domain reconciliation.

Observations preserve source evidence, timestamps, raw payload references, parser/adapter version, and presence state. Reconciliation compares observations with canonical state and issues commands only when domain policy determines that a meaningful state change is supported.

Absence from a source is evidence of absence, not automatic proof of closure.

## Consequences

- source evidence can be reprocessed after parser improvements
- parser/source failures do not silently manufacture domain history
- published time, observed time, ingestion time, and event time remain distinct
- closure confidence can use multiple observations and source health
- historical analytics can distinguish what the source claimed from when LMX learned it
