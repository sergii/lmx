# Analytics

LMX should become a historical labor-market dataset rather than a collection of current pages.

## Vacancy lifecycle

Track at least:

- source_published_at when known
- first_seen_at
- last_confirmed_present_at
- missing_since
- source publication/update dates when available
- first disappearance evidence
- reappearance
- explicit closure evidence
- derived closure confidence/state
- reopen count
- repost count
- source count
- observable lifetime

A vacancy can disappear from one source while remaining visible elsewhere. Market status must therefore be derived from all known postings and evidence, not one URL.

Absence from a source is not automatically closure. Parser/source health must be considered when interpreting missing observations.

## Cross-source publication timeline

For a canonical JobOpening, preserve every posting and distinguish source timestamps from LMX observation timestamps.

This supports questions such as:

- Which source claims the earliest publication time?
- Which source did LMX actually observe first?
- How much lead time does one source have over another?
- How many sources does an employer typically use?
- Does the employer broaden distribution when a role remains unfilled?
- Are reposts synchronized or staggered?

## Hiring activity

Company-level analytics should include:

- new openings by period
- active openings
- close/reopen behavior
- hiring velocity
- repeated role families
- repeated seniority levels
- time between recurring openings

Identity-resolution confidence should be available when company/opening aggregation depends on semantic matching.

## Compensation intelligence

Analyze only evidence with explicit provenance. Preserve original values and normalize copies for comparison.

Useful dimensions:

- currency
- period
- employment context
- location/country
- seniority
- role family
- source
- listed versus inferred evidence

Potential metrics:

- median and percentile compensation
- trend by week/month/quarter
- compensation change within the same opening
- compensation by technology or role family
- compensation by geography

Cross-currency normalization must retain:

- normalized currency
- FX rate
- FX date
- FX source

Charts should be able to separate labor-market changes from currency-conversion changes.

## Demand intelligence

Track demand by:

- skill and technology
- seniority
- role family
- industry/sector
- company type
- geography
- remote policy
- source

## Source intelligence

Measure source quality and behavior:

- freshness
- unique openings discovered
- duplicate rate
- time lead versus other sources
- compensation completeness
- geographic clarity
- parser reliability
- acquisition success/error rate
- response/application friction where measurable

## Data quality

Analytics should expose confidence and evidence coverage. Unknown values remain unknown instead of being silently imputed into factual charts.

Important derived metrics should be reproducible from versioned observations/events and record the resolver/parser/rules version where interpretation materially affects the result.
