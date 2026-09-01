# Domain model

## Core entities

### Company

A canonical organization. Multiple textual names or domains may resolve to one Company.

### JobOpening

The canonical hiring need. One opening can be represented by many publications across many sources and at different times.

Typical properties include canonical title, company, inferred role family, seniority, current market state, first seen, last seen, and canonicalized requirements.

### JobPosting

A concrete publication of a JobOpening on a source. It owns source-specific identifiers, URL, source wording, source timestamps, and source-specific state.

One JobOpening can have many JobPostings.

### PostingSnapshot

An immutable observation of a JobPosting at a point in time. Snapshots preserve source facts before later changes overwrite a projection.

Examples of snapshot fields include title, description hash, compensation text, location wording, remote policy wording, employment type, requirements, and observed availability.

### IngestionRecord

Describes how LMX received an observation. This is separate from where the employer published it.

Examples of ingestion transport include RSS, HTTP API, HTTP scrape, browser crawl, webhook, API submission, manual entry, and import.

### RawPayload

The original payload when practical: HTML, JSON, RSS item, API body, or manual form payload. Raw data can be stored outside PostgreSQL while metadata and hashes remain in PostgreSQL.

Preserving raw input allows old observations to be reprocessed after parser improvements.

### CompensationObservation

Preserves original compensation data and context. Do not collapse everything into one monthly number.

Relevant fields include original text, currency, minimum, maximum, period, gross/net when known, employment context, country context, and evidence level.

Normalized hourly, monthly, and annual values may be computed for analytics, but original source values remain authoritative.

### FitAssessment

A versioned assessment of how attractive an opportunity is. It should keep the model/rules version and evidence used.

Maintain at least two concepts:

- Opportunity Score: overall attractiveness.
- Action Priority: how much attention the opportunity deserves now, considering freshness, source friction, eligibility, and likely speed to a real conversation.

### Application

The user's application or intended application to a JobOpening.

### Interaction

A call, email, message, interview, follow-up, note, or other interaction related to an Application, Company, or Contact.

### Contact

Recruiter, hiring manager, interviewer, or other person involved in the process.

## JobOpening versus JobPosting

A single opening may appear at different times and under slightly different titles on multiple sources. LMX should resolve these to one JobOpening when confidence is sufficient, while preserving every JobPosting and every observation.

Deduplication should combine deterministic and semantic evidence:

1. exact or canonical URL
2. external vacancy identifier
3. canonical application URL
4. company identity
5. normalized title
6. description fingerprint
7. structured requirements similarity
8. semantic similarity
9. LLM review only for ambiguous cases

A company may legitimately have several simultaneous openings with the same title, so company plus title alone is never sufficient proof.

## Geographic eligibility

Geography is an attribute, not a deletion rule.

Store explicit or inferred values such as Ukraine eligibility, Poland eligibility, EU/Europe scope, worldwide scope, US-only constraints, and original employer wording.

If Ukraine is not supported but Poland is supported, the opening stays in the system and may still have a high Opportunity Score. The current restriction can reduce Action Priority without destroying the underlying opportunity assessment.

## Facts versus interpretation

Every extracted field should support an evidence level:

- LISTED: explicitly stated by the source or employer.
- CALCULATED: deterministic conversion from listed facts.
- INFERRED: reasonable interpretation that is not confirmed.
- UNKNOWN: insufficient evidence.

LMX must not invent missing hours, compensation, timezone overlap, or geographic eligibility.
