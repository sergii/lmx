# ADR 0009 - LMX is the system of record; agents are replaceable processors

## Status

Accepted.

## Context

LMX can gain substantial leverage from external agent systems such as OpenBot, GrokBot, P, Hermes, ChatGPT/Codex-driven workers, Claude clients, or future specialized agents.

Those systems can discover vacancies, browse difficult sources, extract structured fields, enrich companies, infer relationships, perform preliminary qualification, and generate candidate/opening analysis.

However, external agents have different memory models, prompts, model versions, tool access, failure modes, and lifecycle. If the ontology or canonical business state lives primarily inside an agent, replacing or rerunning that agent can change the meaning of historical data.

LMX needs durable semantics across processors and over time.

## Decision

LMX remains the canonical system of record for:

- ontology and domain semantics
- Workspace/User/Candidate identity
- Company/OpeningParty/JobOpening/JobPosting identity
- source evidence and observation history
- accepted lifecycle state
- domain events and audit trail
- CandidateProfileVersion history
- versioned MatchAssessments
- Application/Interview state
- accepted recruiting/client state where implemented

External agents are replaceable processors or clients.

Agent output may enter LMX as:

- RawPayload/evidence
- SourceObservation
- extracted/enriched fields with provenance
- identity-resolution proposal
- preliminary qualification
- preliminary or assisted MatchAssessment
- InterviewPrep input/output

Agent-generated interpretation must retain provenance sufficient to compare or rerun it, including where applicable:

- agent/processor identity
- model/version
- prompt/rules/profile version
- input evidence references
- CandidateProfileVersion
- opening/evidence cutoff
- generated_at
- confidence
- structured output

A rerun produces a new derived-analysis version instead of overwriting historical analysis in place.

Canonical domain changes still pass through LMX commands/domain rules/events. Agents never receive implicit permission to update domain tables directly.

## MCP

LMX exposes an MCP server as a first-class interface into the same command/query layer used by the web UI and HTTP API.

External agents can use MCP to query and operate LMX within scoped authorization.

LMX may also invoke an external processor through MCP when that processor exposes a compatible MCP server. HTTP, queue, webhook, or purpose-built adapters are equally valid invocation mechanisms; the protocol does not define domain authority.

## Consequences

Positive:

- agents can be replaced without losing semantic continuity
- multiple processors/models can be compared against identical evidence
- historical MatchAssessments remain explainable
- raw evidence can be reprocessed when extraction improves
- agent hallucination or model drift cannot silently rewrite canonical truth
- ChatGPT/Codex/Grok/OpenBot/Hermes can all work against one stable knowledge/application system

Costs:

- LMX must persist richer provenance and derived-analysis versions
- agent integration requires explicit schemas instead of dumping free-form answers into state
- some decisions require an acceptance/reconciliation step after agent processing

## Principle

Agents provide leverage. LMX owns meaning.