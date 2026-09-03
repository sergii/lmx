# Bounded contexts

LMX uses explicit DDD boundaries so acquisition concerns, canonical market identity, candidate knowledge, application workflow, intelligence, recruiting, and delivery do not collapse into one large model.

The implementation target is a modular monolith. Each major bounded context should map to an explicit package boundary that can be checked by tooling such as Packwerk.

## Workspace / Identity foundation

Owns tenant and authenticated-user boundaries shared by the application.

Responsibilities:

- Workspace
- User
- Membership / workspace access
- explicit workspace execution context
- authentication and authorization foundations

Workspace context must be explicit in service/background execution, for example through a `WorkspaceContext.with(...)` boundary. Do not rely on a pervasive ActiveRecord `default_scope` as the primary tenant mechanism.

PostgreSQL RLS remains a database security boundary where practical.

## Acquisition

Owns external access and raw evidence.

Responsibilities:

- source registry and adapters
- RSS, HTTP API, HTML and browser acquisition
- external agent-assisted acquisition
- raw payload persistence
- source observations
- source health metadata
- acquisition retries and idempotency

Acquisition does not decide personal relevance or directly mutate canonical market entities.

An OpenBot, GrokBot, P, Hermes, or another external agent may act as a replaceable acquisition/enrichment worker. Its output enters LMX as evidence, observations, or preliminary derived data with provenance. The agent is not the canonical system of record.

## Market Catalog

Owns canonical market identity and lifecycle.

Responsibilities:

- Company
- JobOpening
- JobPosting
- OpeningParty relationships such as direct employer, vendor, agency, and end client
- identity resolution
- posting-to-opening links
- reversible merge decisions
- market lifecycle derived from observations
- cross-source publication history

Market Catalog does not infer candidate fit or own personal application state.

## Talent Profile

Owns candidate identity and durable knowledge about candidates.

Responsibilities:

- Candidate
- CandidateProfileVersion
- experience
- skills and competencies
- projects and achievements
- preferences and constraints
- resumes and public profiles
- candidate evidence and assessments

A Candidate is distinct from a User. A personal workspace may link its only User to its only Candidate; a recruiting workspace may contain thousands of Candidates without user accounts.

## Intelligence

Owns derived interpretation, matching, ranking, and analytical products.

Responsibilities:

- MatchAssessment
- Opportunity Score
- Action Priority
- technology/role/industry classification
- geographic interpretation
- compensation interpretation
- preliminary qualification/enrichment supplied by external processors
- market analytical projections

Derived assessments are versioned and must retain candidate-profile version, opening/evidence cutoff, rules/model version, and evidence provenance.

Intelligence may consume external-agent pre-analysis, but it decides how that analysis is represented inside LMX. Agent output never silently becomes canonical truth.

## Personal CRM

Owns candidate opportunity workflow.

Responsibilities:

- OpeningDisposition
- Application and independent repeat application attempts
- application stage and next-action history
- Contact
- Interaction
- Interview
- InterviewPrep
- notes, reminders and next actions
- personal Kanban/list/table read models

Personal CRM workflow history is event-authoritative. It owns the interpretation/reduction of its immutable workflow events and any rebuildable read projections needed for daily queries. Projection tables are private implementation details and are not the system of record.

Personal state is never used as the source of market state.

The same context can support one candidate in a personal workspace or many candidate/application processes in a recruiting workspace without changing the meaning of Application.

## Recruiting

Optional context for recruiting on behalf of a client/vendor.

Responsibilities can include:

- RecruitingEngagement
- client/vendor relationship
- assigned recruiters
- candidate presentations
- client decisions
- recruiting SLA/commercial metadata

Recruiting references shared Candidates and JobOpenings. It must not redefine Company, JobOpening, JobPosting, Candidate, or Application based on a runtime "agency mode" flag.

This context can remain disabled or unimplemented for the initial personal product.

## Delivery

Owns push and presentation-oriented delivery policies.

Responsibilities:

- Telegram notifications
- digest policies
- notification delivery state
- web push/websocket delivery if added later

## Integration

Owns external command/query adapters.

Responsibilities:

- HTTP API
- MCP server exposed by LMX
- webhook ingress
- agent credentials and tool permissions
- external worker invocation adapters
- optional MCP client integrations when an external processor exposes a compatible MCP server
- integration event contracts

Integration adapters call application services. They never bypass bounded-context rules or write domain tables directly.

## Cross-context rules

- Contexts communicate through explicit application APIs and versioned events where asynchronous coupling is useful.
- Internal domain events are not automatically public integration contracts.
- Acquisition produces evidence. Market Catalog decides canonical identity/lifecycle.
- Talent Profile owns candidate knowledge. Intelligence consumes candidate-profile versions but does not rewrite them.
- Intelligence consumes canonical facts and observations but does not rewrite source evidence.
- Personal CRM references Candidate and JobOpening identities without owning candidate-profile history or market lifecycle.
- Personal CRM projections may cache cross-opportunity workflow state, but consumers access them only through Personal CRM public APIs.
- Recruiting composes shared domain identities rather than introducing alternate meanings for them.
- Delivery reacts to application/integration events and does not own business state.
- Integration exposes controlled boundaries to agents and external systems.

## Package dependency direction

The modular monolith should keep dependencies explicit and narrow. A target dependency shape is:

```text
Workspace/Identity foundation
        ^
        |
Acquisition      Talent Profile
     \             /
      \           /
       Market Catalog
             \   /
          Intelligence
               |
          Personal CRM
               |
            Delivery

Integration -> public application interfaces of all required contexts
Recruiting   -> public application interfaces of Market Catalog, Talent Profile and Personal CRM
```

This diagram is directional guidance, not permission for direct model coupling. Cross-context use should prefer public package APIs, commands, queries, and events.
