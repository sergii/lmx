# Bounded contexts

LMX uses explicit DDD boundaries so acquisition concerns, canonical market identity, personal workflow, intelligence, and delivery do not collapse into one large model.

## Acquisition

Owns external access and raw evidence.

Responsibilities:

- source registry and adapters
- RSS, HTTP API, HTML and browser acquisition
- raw payload persistence
- source observations
- source health metadata
- acquisition retries and idempotency

Acquisition does not decide personal relevance or directly mutate canonical market entities.

## Market Catalog

Owns canonical market identity and lifecycle.

Responsibilities:

- Company
- JobOpening
- JobPosting
- identity resolution
- posting-to-opening links
- reversible merge decisions
- market lifecycle derived from observations
- cross-source publication history

## Intelligence

Owns derived interpretation and ranking.

Responsibilities:

- FitAssessment
- Opportunity Score
- Action Priority
- technology/role/industry classification
- market analytical projections

Derived assessments are versioned and must retain evidence/model/rules provenance.

## Personal CRM

Owns the user's workflow.

Responsibilities:

- Application
- application attempts and stages
- Contact
- Interaction
- notes, reminders and next actions
- personal Kanban state

Personal state is never used as the source of market state.

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
- MCP
- webhook ingress
- agent credentials and tool permissions
- integration event contracts

Integration adapters call application services. They never bypass bounded-context rules or write domain tables directly.

## Cross-context rules

- Contexts communicate through explicit application APIs and versioned events where asynchronous coupling is useful.
- Internal domain events are not automatically public integration contracts.
- Acquisition produces evidence. Market Catalog decides canonical identity/lifecycle.
- Intelligence consumes canonical facts and observations but does not rewrite source evidence.
- Personal CRM can reference JobOpening/JobPosting identities without owning their market lifecycle.
