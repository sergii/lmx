# Acquisition

The Acquisition bounded context owns how LMX retrieves and preserves external evidence. It does not decide whether two observations describe the same real-world opening and it never mutates Market Catalog aggregates directly.

## Phase 0 persistence contract

The durable chain is:

```text
SourceRun -> RawPayload -> IngestionRecord -> SourceObservation
```

### SourceRun

`SourceRun` records one acquisition attempt for a source. It preserves the source key, acquisition transport, start/finish times, collector/adapter/parser versions, counts where meaningful, failure details, and replay/source-health provenance.

A terminal run is either `succeeded` or `failed`. A successful run with `observed_count = 0` is intentionally different from a failed run. Terminal outcome data is immutable.

Acquisition transports describe how external source evidence was retrieved. They are deliberately distinct from ingress interfaces such as API, webhook, MCP, import, or manual web entry.

### RawPayload

`RawPayload` preserves source material when practical together with a SHA-256 digest, content type, encoding, source URI, capture time, byte size, and provenance.

Pass a `String` when byte-for-byte source material is available. The body is stored as binary data so its digest describes the exact persisted bytes. Structured Ruby/JSON input is serialized deterministically as a pragmatic fallback.

Persisted raw payloads are immutable and can survive parser failure independently of observations. They can also be reused by a later parser version for replay/reprocessing.

### IngestionRecord

`IngestionRecord` records how a raw capture was processed into LMX evidence. It links the source run and raw payload to one or more observations and keeps collector/adapter/parser versions plus provenance. An optional `ingress_interface` records how an external collector or agent submitted evidence to LMX without confusing that interface with the source run's acquisition transport. A newer parser may create a new ingestion record against the same immutable raw payload.

### SourceObservation

`SourceObservation` is immutable evidence of what a source showed at a point in time. It retains source and ingestion timestamps, source IDs/URLs, presence evidence, parser version, raw-payload digest/reference, structured factual output, and metadata.

An observation is not a `JobPosting` and is not a domain event by itself. Reconciliation in Market Catalog consumes observations through an explicit package boundary and decides whether canonical state should change.

## Public application API

Collectors and integrations should use the narrow Acquisition application APIs instead of writing package models directly:

```ruby
source_run = Acquisition::SourceRuns.start(...)
raw_payload = Acquisition::RecordRawPayload.call(source_run:, ...)
observation = Acquisition::RecordSourceObservation.call(source_run:, raw_payload:, ...)
Acquisition::SourceRuns.succeed(source_run:, observed_count: 0, ...)
```

`RecordSourceObservation` may also receive raw input directly as a convenience. For collectors that must preserve evidence even when parsing fails, record the `RawPayload` first and then process it.

Failures use `Acquisition::SourceRuns.fail`. Start, completion, raw capture, ingestion, and observation recording are idempotent for the same identity. Reusing an idempotency identity with conflicting evidence raises an explicit conflict rather than silently rewriting history.

## Historical replay and reprocessing

`Acquisition::Replay` reapplies the current source parser to retained raw evidence without refetching the external source or rewriting historical observations. Dry-run is the default. It reports semantic `added`, `changed`, `unchanged`, and `removed` interpretations before any new evidence is appended.

Replay can be scoped by source and capture time:

```sh
bin/rails lmx:acquisition:replay SOURCE=dou FROM=2026-09-01 TO=2026-09-05
```

or to exact immutable `SourceObservation` public IDs:

```sh
bin/rails lmx:acquisition:replay \
  SOURCE=dou \
  OBSERVATIONS=source_observation_01...,source_observation_01...
```

`FROM`, `TO`, and `LIMIT` remain additional raw-capture constraints for an exact-observation selection. Set `APPLY=true` only after reviewing the dry-run diff:

```sh
bin/rails lmx:acquisition:replay SOURCE=dou FROM=2026-09-01 TO=2026-09-05 APPLY=true
```

Applying replay creates new `IngestionRecord` / `SourceObservation` evidence with the current `parser_version`; older observations, parser versions, raw bytes, and evidence remain immutable. Repeating the same replay with the same parser is idempotent and appends nothing new.

Replay deliberately stops at the Acquisition boundary. It never emits Market Catalog domain events itself. Downstream reconciliation consumes the resulting observations and is responsible for material-change detection and event idempotency, so an acquisition replay cannot directly duplicate accepted domain events.

Every selected observation must still resolve to its retained raw payload. Exact-observation replay raises `Acquisition::Replay::MissingRawPayload` rather than silently skipping evidence when that invariant is broken, making legacy/corrupt evidence explicit before a large reprocessing run.

## DOU Phase 0 vertical slice

`Acquisition::Dou.collect` is the first source-specific collector. The canonical DOU acquisition order is RSS first and ordinary public HTML second:

```text
rss       -> https://jobs.dou.ua/vacancies/feeds/  -> persisted transport `rss`
http_html -> https://jobs.dou.ua/vacancies/        -> persisted transport `http_scrape`
```

RSS is the default because DOU exposes a first-party vacancy feed with stable item URLs and `pubDate`, making frequent polling cheaper and less brittle than page parsing. HTML remains an explicit fallback and provides richer listing-card fields such as company and location text. Browser acquisition stays configured only as a later fallback/evaluation path; this collector does not use DOU's XHR load endpoint, login, or anti-bot bypasses.

A single `SourceRun` always represents one acquisition transport. The collector does not silently switch from RSS to HTML after a failure because that would blur source-health and replay provenance. A scheduler may start a separate fallback HTML run when policy requires it.

```ruby
# Canonical primary strategy from config/sources.yml: RSS
result = Acquisition::Dou.collect(
  search: "Ruby",
  run_key: "dou:rss:ruby:2026-09-02T20:00:00Z",
  started_at: Time.current
)

# Explicit fallback transport
fallback = Acquisition::Dou.collect(
  search: "Ruby",
  strategy: "http_html",
  run_key: "dou:html:ruby:2026-09-02T20:00:00Z",
  started_at: Time.current
)
```

Both adapters persist the exact raw response before parsing, record an `IngestionRecord` even for zero-result runs, and emit immutable `SourceObservation` rows only for explicit source facts. RSS `pubDate` is preserved as `source_published_at`; no company/location inference is fabricated from feed titles. Retrying the exact same run identity returns the prior terminal result without another HTTP request or duplicate evidence. Parser failures still preserve raw material and ingestion provenance.

For an operator-triggered run:

```sh
bin/rails lmx:acquisition:dou SEARCH=Ruby
bin/rails lmx:acquisition:dou SEARCH=Ruby STRATEGY=http_html
```

Set `RUN_KEY` when an external scheduler needs a stable retry identity.
