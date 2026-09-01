# Roadmap

## Phase 0 - Capture evidence immediately

Goal: start accumulating durable history before the full application architecture and UI are complete.

The ordered implementation plan, dependencies, first-24-hours target, and completion gate live in [`phase-0-execution.md`](phase-0-execution.md).

Day-one priority:

- get the first highest-priority source observations into durable append-only storage
- persist source timestamps, `observed_at`, raw payload references/hashes, and adapter/parser version
- avoid losing historical evidence while the canonical domain pipeline is still being built

In parallel, establish the durable architecture:

- adopt/clean the existing Rails/PostgreSQL/Inertia application foundation
- explicit `WorkspaceContext.with(...)` execution boundary for jobs, collectors, replay, MCP and scripts
- PostgreSQL RLS retained as a database tenant-security boundary
- domain-driven modular-monolith package skeleton
- Packwerk (or equivalent) boundary checks in CI
- source registry loader and schema validation
- search/ranking profile loader
- SourceObservation model and observation identity/idempotency
- Event Store envelope and aggregate versioning
- Transactional Inbox and Outbox
- initial Acquisition, Market Catalog, Talent Profile, Intelligence, Personal CRM, Delivery and Integration boundaries
- JobOpening versus JobPosting resolver
- OpeningParty semantics for employer/vendor/agency/end-client relationships
- reversible ResolutionDecision records
- lifecycle reconciliation that distinguishes missing from closed
- basic OpenTelemetry and source-health signals

Temporary collectors or external-agent workers are acceptable if they preserve enough raw evidence and provenance to reprocess later.

## Phase 1 - Daily usable personal product

- canonical opening list
- Candidate profile for the workspace user
- immutable/versioned CandidateProfileVersion snapshots
- versioned MatchAssessment between Candidate and JobOpening
- Opportunity Score and Action Priority
- strengths/gaps/risks/recommendation/interview-angle output with provenance
- Telegram near-real-time notifications
- manual URL submission
- manual no-URL entry
- personal Applications with repeat applications allowed
- Kanban/list/table representations
- next action / next-action time
- opening detail with source/observation history
- first local/fast source adapters operating continuously

The product should already be useful every day at this phase: discover opportunities, understand why they match, decide what to do next, and track the application process.

## Phase 2 - Broader discovery and agent-assisted acquisition

- expand adapters according to `config/sources.yml`
- API submission
- webhook ingestion
- MCP query/write ingress
- LMX MCP server for ChatGPT, Codex, Grok/OpenBot/P/Hermes-style clients and custom agents
- external worker adapter for discovery/extraction/enrichment/pre-analysis
- agent-returned raw evidence and preliminary analysis with processor/model/rules provenance
- robust browser fallback where justified
- direct company-career adapters/platform families
- richer geographic and compensation extraction
- company/vendor/end-client enrichment
- source health dashboard
- access/robots/terms/rate-limit review as sources become operational

External agents remain replaceable processors. LMX remains the system of record for ontology, canonical identities, accepted facts, MatchAssessments, applications, and audit history.

## Phase 3 - Personal intelligence and interview operating loop

- richer Candidate knowledge model: experience, skills, projects, achievements, preferences, constraints, resumes and evidence
- Contact and Interaction timeline
- Interview scheduling/state
- versioned InterviewPrep generated from candidate/opening/company/vendor/end-client/interviewer evidence
- likely interview topics and candidate stories to prepare
- questions to ask and risks to verify
- transcript/notes ingestion
- evidence extraction from completed interviews
- compare predicted interview focus with actual interview outcome
- use accepted interview evidence to create new candidate-profile/assessment versions

This creates the learning loop:

```text
Market -> Match -> Application -> Interview Prep -> Interview
   ^                                              |
   |                                              v
   +---- improved candidate/company evidence <----+
```

## Phase 4 - Market intelligence

After enough history exists:

- vacancy lifetime analytics with closure confidence
- repost/reopen analysis
- company hiring velocity
- cross-source publication/observation timelines
- compensation trends with historical FX metadata
- demand by technology, seniority, industry and geography
- source effectiveness analytics
- identity-resolution quality/confidence analytics
- vendor/end-client relationship intelligence
- candidate/profile-to-market gap analytics

## Phase 5 - Agent-native operation

- production-hardened MCP server
- scoped credentials and tool permissions
- principal/actor/executor/client provenance views
- commands from multiple AI clients
- LMX-initiated external processor jobs through MCP/API/queue adapters
- compare multiple agent/model analyses against the same evidence
- agent-assisted enrichment and ambiguous identity resolution
- reversible merge/relink tools
- audit UI based on observations, commands, domain events and derived-analysis versions

## Phase 6 - Recruiting mode

Enable the same semantic core for recruiting/hiring without redefining personal-mode entities:

- many Candidates per Workspace
- optional RecruitingEngagement context
- client/vendor relationships
- assigned recruiters
- candidate presentation workflow
- client decisions
- hiring for own company or on behalf of a client
- workspace/module configuration controlling UX rather than changing core ontology

A staffing/outstaffing scenario such as a vendor publishing an opening for an end client is represented through OpeningParty relationships and RecruitingEngagement, not through alternate meanings of JobOpening or Candidate.

## Phase 7 - Scale only when justified

- search engine if PostgreSQL search is insufficient
- ClickHouse if analytical/event volume requires it
- dedicated stream infrastructure only if throughput or consumer independence requires it
- extract a modular-monolith package into a separately deployed service only when scale/team/deployment pressure justifies it

Avoid premature infrastructure complexity while preserving boundaries that allow later extraction.