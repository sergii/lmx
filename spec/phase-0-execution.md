# Phase 0 execution

## Goal

Start accumulating trustworthy historical market evidence immediately, then add the minimum domain/event machinery needed to turn that evidence into canonical openings and real-time signals.

Phase 0 optimizes for **time-to-first-durable-observation**, not UI completeness.

## First 24 hours

The first successful slice should be:

```text
DOU
  -> acquire raw response
  -> persist RawPayload metadata/reference
  -> persist IngestionRecord
  -> persist immutable SourceObservation
  -> repeat safely
```

Success means real observations are accumulating with source timestamps, `observed_at`, payload hashes/references, source identifiers, and parser/adapter version. Canonical deduplication, scoring, Telegram, and polished UI must not block this milestone.

## Critical path

1. Runtime + PostgreSQL foundation - #1
2. Machine-readable source/profile config loader and validation - #2
3. Durable RawPayload / IngestionRecord / SourceObservation persistence - #3
4. First DOU acquisition adapter - #4
5. Djinni adapter - #5
6. Work.ua + Robota.ua adapters - #6
7. Transactional Inbox + Event Store + Outbox - #7
8. Minimal reversible JobPosting / JobOpening resolution - #8
9. Presence/lifecycle evidence: missing is not closed - #9
10. Telegram near-real-time delivery - #10
11. OpenTelemetry + source health - #11
12. Replay/reprocessing of historical observations - #12

Items 1-4 are the shortest path to the first valuable asset: historical evidence that did not exist before LMX captured it.

## Parallel work

Once #3 defines the observation contract, adapter work can proceed in parallel. Domain/event work can proceed without waiting for every source adapter. Observability should be added early enough that an empty/broken source cannot silently look healthy.

```text
#1 Runtime
 |
 +--> #2 Config
 |
 +--> #3 Observation persistence
       |
       +--> #4 DOU --------+
       +--> #5 Djinni -----+--> continuous acquisition
       +--> #6 Work/Robota +
       |
       +--> #7 Inbox/Event Store/Outbox
              |
              +--> #8 Identity resolution
              |      |
              |      +--> #9 Lifecycle evidence
              |      |
              |      +--> #10 Telegram
              |
              +--> #11 Observability

#3 + raw payload retention --> #12 Replay/reprocessing
```

## Minimal persistence model

Phase 0 should support at least these durable concepts:

### Acquisition

- `source_runs`
- `raw_payloads`
- `ingestion_records`
- `source_observations`

A source run records whether a collector actually succeeded. A zero-result successful run must be distinguishable from a parser/auth/network failure.

### Market catalog

- `companies`
- `job_postings`
- `job_openings`
- `resolution_decisions`
- read projections needed to inspect canonical state

### Event/reliability infrastructure

- `inbox_messages`
- `domain_events`
- `outbox_messages`

Exact Rails table names are implementation details. The domain distinctions are not.

## SourceObservation minimum contract

Each accepted observation should preserve enough evidence to be reprocessed later:

- source ID
- source run ID
- external source ID when available
- original URL
- canonical URL candidate
- raw payload reference/hash
- parser/adapter version
- `source_published_at` when explicitly available
- `source_updated_at` when explicitly available
- `observed_at`
- `ingested_at`
- presence evidence
- factual extracted fields plus evidence level

Important evidence levels remain:

- `LISTED`
- `CALCULATED`
- `INFERRED`
- `UNKNOWN`

Unknown data must remain unknown.

## First extraction contract

Adapters should converge on one factual extraction shape. At minimum:

- company wording
- title
- description
- source identifiers
- URLs/application URL when available
- compensation original text and structured values when explicit
- compensation period/currency
- employment type when explicit
- location wording
- remote policy wording
- geographic restrictions/eligibility when supported by evidence
- hours/schedule/timezone only when explicitly available

Do not infer whether a job can coexist with another job. That is not collector responsibility.

## Identity resolution order

Start deterministic and add semantic/LLM assistance only for ambiguity:

1. source external ID
2. exact/canonical URL
3. canonical application URL
4. canonical company identity
5. normalized title
6. description fingerprint
7. structured requirement similarity
8. semantic similarity
9. LLM review for ambiguous cases

Every non-trivial link/merge should create a versioned `ResolutionDecision` with confidence and evidence. Link and merge decisions must be reversible.

## Presence and closure

A posting that is absent from one scan is not closed.

Phase 0 must preserve:

- `last_confirmed_present_at`
- `missing_since`
- consecutive absence evidence
- source run health at the time of absence
- explicit closed/expired evidence when available
- active state of sibling postings for the same opening

A parser failure, authentication failure, pagination change, source outage, or rate limit must never manufacture a vacancy closure.

## Continuous collection

After each adapter works once, make it unattended.

Scheduling requirements:

- sources run independently
- cadence is configurable
- overlapping runs are prevented or safe
- retries/backoff are explicit
- one broken source cannot block others
- local-fast sources may use a higher cadence than broad international sources

Do not over-design high availability. Continuous evidence capture is the goal.

## Event boundary

Collectors and parsers produce evidence. They do not directly mutate canonical market state.

```text
SourceObservation
   -> reconciliation
   -> Command
   -> domain rules
   -> Domain Event
   -> projection / Outbox
```

External commands pass through the Transactional Inbox. Accepted domain changes append immutable events and corresponding Outbox records atomically where required.

## Telegram Phase 0 slice

Telegram can arrive before the full web application.

Initial notifications should cover:

- newly discovered local/fast opportunities
- materially changed postings
- compensation changes
- repost/reopen signals once lifecycle confidence exists

Delivery must be idempotent and observable.

## Observability gate

At minimum expose per source:

- last attempted run
- last successful run
- acquisition duration
- result/observation count
- fetch errors
- parser errors
- consecutive failures
- adapter/parser version

The system must distinguish "no new jobs" from "collector is broken".

## Replay gate

Before Phase 0 closes, previously collected observations must be replayable through newer parser/normalizer/resolver versions without deleting old evidence.

A source/date scoped dry-run or diff mode is preferred before bulk reprocessing.

## Explicitly deferred to Phase 1+

Do not block Phase 0 on:

- polished Kanban
- full ATS workflow
- rich analytics dashboards
- ClickHouse
- dedicated Kafka/Redpanda/NATS infrastructure
- production-grade MCP tool catalog
- every international source
- advanced LLM scoring
- sophisticated browser automation where HTTP/RSS/API acquisition is sufficient

## Phase 0 completion gate

Phase 0 is complete when all of the following are true:

- DOU, Djinni, Work.ua, and Robota.ua continuously produce durable observations
- raw evidence and observation timestamps are preserved
- collectors have explicit run health
- canonical Company, JobPosting, and JobOpening projections exist
- cross-source resolution is reversible and auditable
- missing/closed semantics cannot be corrupted by one failed scan
- Transactional Inbox, Event Store, and Outbox are operational
- Telegram can surface new/materially changed opportunities
- OpenTelemetry/source-health signals make broken adapters visible
- historical observations can be replayed/reprocessed

At that point Phase 1 can focus on the daily product experience: list, opening detail, personal application workflow, Kanban, and richer ranking.