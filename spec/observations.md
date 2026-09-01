# Observations and evidence

LMX distinguishes what an external source showed from what the domain concludes.

## SourceObservation

A SourceObservation is immutable evidence captured from a source at a point in time.

Typical fields:

- source_id
- external_id when available
- canonical_url candidate
- raw_payload_ref
- payload_hash
- observed_at
- source_published_at when explicitly available
- source_updated_at when explicitly available
- presence_state
- extracted factual fields with evidence levels
- parser/adapter version
- ingestion record

A new observation does not automatically mean `job_posting.updated`. Reconciliation compares evidence with existing canonical state and may issue a domain command.

## Time semantics

Do not collapse all timestamps into `created_at`.

Important concepts:

- `source_published_at` - publication time claimed by the source/employer.
- `source_updated_at` - update time claimed by the source/employer.
- `observed_at` - when LMX actually observed the evidence.
- `ingested_at` - when the observation entered LMX processing/storage.
- `occurred_at` - when a domain fact/event occurred in LMX.
- `effective_at` - when a domain fact is considered effective, if different from event processing time.
- `first_seen_at` - earliest LMX observation of a canonical entity/posting.
- `last_seen_at` - most recent confirmed presence observation.

Historical analytics must preserve the difference between source time and observation time.

## Presence and absence

A missing page or missing search result is not sufficient proof that a vacancy closed.

Preserve evidence such as:

- `last_confirmed_present_at`
- `missing_since`
- consecutive absence observations
- source/adapter health at the time of absence
- explicit closed/expired wording when available
- HTTP status or redirect evidence
- whether other known postings remain active

Suggested derived lifecycle concepts:

- observed
- missing
- probably_closed
- closed
- reappeared

`closed` should require explicit evidence or a policy based on multiple trustworthy absence observations. A parser failure, authentication failure, pagination change, source outage, or rate limit must not manufacture a closure event.

## Evidence levels

Every extracted or derived fact supports an evidence level:

- LISTED - explicitly stated by source/employer.
- CALCULATED - deterministic transformation of listed facts.
- INFERRED - interpretation not directly confirmed.
- UNKNOWN - insufficient evidence.

Evidence should retain its source observation and extraction/parser version where practical.

## Reconciliation

Conceptual flow:

```text
RawPayload
    |
    v
SourceObservation
    |
    v
Normalization / extraction
    |
    v
Identity resolution + reconciliation
    |
    +--> no domain change
    |
    +--> Command
            |
            v
        Domain Event
```

This boundary prevents crawlers and parsers from becoming hidden writers of canonical state.
