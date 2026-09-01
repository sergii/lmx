# Domain model

## Core entities

### Workspace

The tenant boundary for LMX. A Workspace owns access, configuration, personal/recruiting state, candidate profiles, and tenant-scoped derived data.

A personal installation is still a Workspace. The initial case may contain one User and one Candidate representing the same person, but those identities remain separate concepts.

### User

A person who can authenticate and operate LMX.

A User may be linked to a Candidate profile, but many Candidates may never have a User account. This distinction allows the same model to support a personal workspace today and a recruiting workspace with many candidates later.

### Candidate

A person whose suitability for opportunities can be analyzed and whose application process can be tracked.

Candidate is a first-class domain concept, not merely the currently authenticated User.

Typical related information includes experience, skills, projects, achievements, education, preferences, constraints, career goals, resumes, public profiles, notes, evidence, and assessments.

### CandidateProfileVersion

An immutable/versioned representation of the candidate information used for a particular assessment.

Match results must be explainable against the candidate profile that existed when the assessment was produced. New experience, skills, preferences, constraints, resumes, or evidence can produce a new profile version without rewriting historical assessments.

### Company

A canonical organization. Multiple textual names, domains, brands, or source-specific identities may resolve to one Company.

A Company can participate in an opening in several roles. The publisher of a posting is not necessarily the end client or ultimate employer.

### OpeningParty

Represents a Company's role in relation to a JobOpening.

Useful roles include:

- direct_employer
- end_client
- staffing_vendor
- recruiting_agency
- employer_of_record
- contracting_party

Roles can be known, partially known, or evidence-backed hypotheses. For example, a posting can say only "US healthcare client" without identifying the end client. LMX must preserve that uncertainty rather than invent a Company.

### JobOpening

The canonical hiring need. One opening can be represented by many publications across many sources and at different times.

Typical properties include canonical title, role family, seniority, current derived market state, first seen, last seen, canonicalized requirements, and related OpeningParties.

A JobOpening is independent from any particular source publication and independent from whether the workspace has applied to it.

### JobPosting

A concrete publication of a JobOpening on a source. It owns source-specific identifiers, URL, source wording, source timestamps, publisher identity when known, and source-specific lifecycle.

One JobOpening can have many JobPostings.

### SourceObservation

Immutable evidence of what a source showed at a specific time. Observations are inputs to reconciliation, not automatic mutations of canonical state.

See `observations.md` for time and absence semantics.

### PostingSnapshot

An immutable normalized view of a JobPosting observation at a point in time. Snapshots preserve source facts before later changes alter projections.

Examples include title, description hash, compensation text, location wording, remote policy wording, employment type, requirements, and observed availability.

### IngestionRecord

Describes how LMX received evidence. This is separate from where the employer published it.

Acquisition transports include RSS, HTTP API, HTML retrieval and browser automation. Ingress interfaces such as manual entry, API, webhook, MCP and import are separate application entry points.

External agents can also submit evidence or preliminary interpretation, but they do not become the canonical system of record.

### RawPayload

The original payload when practical: HTML, JSON, RSS item, API body, agent-returned source material, or manual form payload. Raw data can be stored outside PostgreSQL while metadata and hashes remain in PostgreSQL.

Preserving raw input allows historical observations to be reprocessed after parser, rules, or model improvements.

### ResolutionDecision

An explainable, versioned identity-resolution decision linking a JobPosting to a JobOpening or merging canonical identities.

Store sufficient evidence to explain and reverse a decision:

- resolver/rules/model version
- confidence
- deterministic evidence
- semantic similarity evidence
- actor/executor when manually or agent-assisted
- decision timestamp

Identity changes must support unlink/relink and merge-revert operations.

### CompensationObservation

Preserves original compensation data and context. Do not collapse everything into one monthly number.

Relevant fields include original text, currency, minimum, maximum, period, gross/net when known, employment context, country context, and evidence level.

Normalized hourly, monthly and annual values may be computed for analytics, but original source values remain authoritative.

Cross-currency analytics must retain conversion metadata:

- normalized currency
- conversion rate
- conversion date
- conversion source

Historical charts must not confuse exchange-rate movement with labor-market compensation movement.

### MatchAssessment

A versioned assessment of a Candidate against a JobOpening.

The assessment is derived intelligence, not raw truth. It should retain at least:

- candidate_id
- candidate_profile_version
- job_opening_id
- opening/version or evidence cutoff used
- Opportunity Score
- Action Priority
- strengths
- gaps
- risks
- recommendation
- interview angles
- rules/scoring policy version
- processor/model version when AI-assisted
- evidence references
- created_at

A historical MatchAssessment is never silently rewritten when the candidate profile, opening, rules, or model changes. A new assessment version is produced instead.

Opportunity Score and Action Priority remain separate concepts:

- Opportunity Score - overall attractiveness and fit.
- Action Priority - how much attention the opportunity deserves now, considering freshness, source friction, eligibility, likely speed to a real conversation, and other time-sensitive factors.

### Application

One concrete application attempt by a Candidate related to a JobOpening, optionally through a specific JobPosting.

Do not enforce one permanent Application per candidate/opening. The same opening can reopen, or the same candidate can apply again through a different path months later.

Useful fields include candidate_id, job_opening_id, via_posting_id, applied time, current personal stage, source/channel, next action, and next-action time.

Application stage history should be represented by immutable domain events/projections rather than destructive status replacement without history.

### Interaction

A call, email, message, interview, follow-up, note, or other interaction related to an Application, Company, Contact, or Candidate.

### Contact

Recruiter, hiring manager, interviewer, vendor representative, end-client representative, or other person involved in the process.

### Interview

A structured interaction associated with an Application. It may retain schedule, participants, transcript/notes, recording references, evidence, preparation, and assessment.

### InterviewPrep

A versioned preparation artifact generated from the candidate profile, opening, companies/parties, public evidence, prior interactions, and relevant external intelligence.

It can contain likely topics, candidate stories to prepare, gaps, questions to ask, company/client context, risks, and evidence references. It is derived intelligence and must retain provenance.

### RecruitingEngagement

An optional future recruiting-context entity for work performed on behalf of a client or vendor.

It can reference shared JobOpenings and Candidates while owning recruiting-specific concepts such as client relationship, assigned recruiters, candidate presentation, SLA, commercial terms, and client decisions.

RecruitingEngagement must not redefine JobOpening semantics. Personal search and agency recruiting should share the canonical market model rather than switch the meaning of core entities based on a mode flag.

## Key relationships

```text
Workspace
├── Users
└── Candidates
      └── CandidateProfileVersions

Company ── OpeningParty ── JobOpening
                              │
                              ├── JobPostings
                              │      └── SourceObservations
                              │
Candidate ───────────────── MatchAssessment
   │
   └── Applications ── JobOpening
          ├── Interactions
          ├── Contacts
          └── Interviews
                 └── InterviewPrep
```

## JobOpening versus JobPosting

A single opening may appear at different times and under slightly different titles on multiple sources. LMX should resolve these to one JobOpening when confidence is sufficient, while preserving every JobPosting and observation.

Deduplication combines deterministic and semantic evidence:

1. exact or canonical URL
2. external vacancy identifier
3. canonical application URL
4. company/party identity
5. normalized title
6. description fingerprint
7. structured requirements similarity
8. semantic similarity
9. LLM review only for ambiguous cases

A company may legitimately have several simultaneous openings with the same title, so company plus title alone is never sufficient proof.

Resolution must be reversible. Incorrect links or merges must be correctable without deleting historical evidence.

## Publisher, vendor, employer and end client

Do not assume that the Company publishing a JobPosting is the Company receiving the work.

Examples include staffing vendors, outsourcing/outstaffing vendors, recruiting agencies, employers of record, and undisclosed end clients.

LMX models these relationships explicitly through OpeningParty and evidence. Unknown end clients remain unknown until supported by evidence.

## Geographic eligibility

Geography is an attribute, not a deletion rule.

Store explicit or inferred values such as Ukraine eligibility, Poland eligibility, EU/Europe scope, worldwide scope, US-only constraints, and original employer wording.

If Ukraine is not supported but Poland is supported, the opening stays in the system and may still have a high Opportunity Score. The current restriction can reduce Action Priority without destroying the underlying opportunity assessment.

## Facts versus interpretation

Every extracted field should support an evidence level:

- LISTED - explicitly stated by the source or employer.
- CALCULATED - deterministic conversion from listed facts.
- INFERRED - reasonable interpretation that is not confirmed.
- UNKNOWN - insufficient evidence.

LMX must not invent missing hours, compensation, timezone overlap, geographic eligibility, end-client identity, or closure state.

External agent output follows the same rule: agent-generated interpretation is evidence-backed, versioned derived data until accepted by deterministic/domain rules where appropriate.