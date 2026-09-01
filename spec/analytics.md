# Analytics

LMX should become a historical labor-market dataset rather than a collection of current pages.

## Vacancy lifecycle

Track at least:

- first_seen_at
- last_seen_at
- source publication dates when available
- first disappearance
- reappearance
- closure
- reopen count
- repost count
- source count
- lifetime while observable

A vacancy can disappear from one source while remaining visible elsewhere. Market status must therefore be derived from all known postings, not one URL.

## Cross-source publication timeline

For a canonical JobOpening, preserve every posting and the time each source was first and last observed.

This supports questions such as:

- Which source receives an opening first?
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
- response/application friction where measurable

## Data quality

Analytics should expose confidence and evidence coverage. Unknown values remain unknown instead of being silently imputed into factual charts.
