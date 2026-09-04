# Interfaces and agents

## API

LMX should expose a versioned API for machine and human tooling.

Candidate capabilities:

```text
openings.search
openings.get
openings.submit
postings.submit
postings.get
observations.submit
companies.get
companies.enrich
candidates.get
candidates.profile
matches.get
matches.assess
applications.create
applications.update
applications.advance
interviews.get
interviews.prepare
market.query
```

External write operations become commands. API handlers must not bypass the domain model.

## MCP

MCP is a first-class adapter into the same application command/query layer used by HTTP and the web application.

Expected clients include:

- Grok Bot
- OpenBot-style agents
- P
- Hermes
- ChatGPT
- Codex
- Anthropic/Claude clients
- custom agents

MCP clients are not granted direct database access. Tools resolve to queries or commands, with authentication, authorization, idempotency, evidence/provenance, and auditability.

Conceptual flow:

```text
Grok Bot ------+
OpenBot -------+
P -------------+
Hermes --------+
ChatGPT -------+
Codex ---------+--> LMX MCP --> application commands/queries --> domain
Claude --------+
custom agents -+
```

## Two agent roles

External agents can participate in LMX in two fundamentally different ways.

### Agent as LMX client

The agent uses LMX MCP/API to query or mutate the system within granted capabilities.

Examples:

- search the market
- inspect a candidate profile
- retrieve top MatchAssessments
- create/advance an Application
- inspect tomorrow's interview
- request interview preparation
- annotate evidence

### Agent as external processor

LMX or an external scheduler asks an agent to perform discovery, extraction, enrichment, or preliminary analysis.

Examples:

- retrieve a difficult source
- extract structured vacancy data
- enrich a company
- infer likely technology/industry labels
- produce a preliminary candidate/opening match
- investigate vendor/end-client relationships

Processor output returns to LMX as raw evidence, SourceObservations, enrichment records, or versioned preliminary assessments. It never becomes canonical state merely because an agent produced it.

LMX remains the system of record for ontology, accepted domain facts, versioned assessments, application state, and audit history.

## External processor invocation

LMX may call external processors through:

- HTTP APIs
- queues/webhooks
- purpose-built adapters
- MCP when the external processor exposes a compatible MCP server

This direction is separate from LMX exposing its own MCP server to agent clients.

The invocation protocol can change without changing domain semantics.

## Ingress interfaces

Ingress interfaces are different from source-acquisition transports.

Supported/planned ingress classes:

- web/manual
- HTTP API
- webhook
- MCP
- import

All write-capable ingress interfaces converge on Transactional Inbox + application command handling.

Manual opening ingress accepts either a vacancy URL or no URL at all. A URL is evidence about a publication and can produce or reuse a JobPosting identity. A no-URL submission can still create a canonical JobOpening for private recruiter messages, referrals, conversations, or other opportunities without a public page.

The word `manual` describes how evidence entered LMX, not where the vacancy was published. Manual submission must therefore remain provenance (`ingress_interface = web/manual`) rather than inventing a market source named `manual`. Known URL hosts can retain their real source key; unknown hosts may use a generic web source class while preserving the original host and URL.

Submitting the same URL through a different command should reuse an existing JobPosting/JobOpening when stable identity matches. Replaying the same command identifier must not duplicate canonical state or events. A no-URL submission has no external identity signal, so a distinct command represents a distinct manually captured opportunity unless later identity resolution merges it.

## Versioned agent analysis

Any agent-assisted interpretation that influences later decisions should retain enough provenance to reproduce or compare it:

- processor/agent identity
- model/version when applicable
- prompt/rules/profile version when applicable
- input evidence/observation references
- candidate profile version when candidate-specific
- opening/evidence cutoff when opening-specific
- confidence when meaningful
- generated_at
- structured output

A rerun creates a new version. Historical analysis is not overwritten in place.

## MatchAssessment through agents

A MatchAssessment belongs to LMX even when an external agent helps produce it.

The agent can calculate or suggest:

- strengths
- gaps
- risks
- recommendation
- Opportunity Score inputs
- Action Priority inputs
- interview angles

LMX stores the assessment with candidate-profile version, opening/evidence version, scoring-policy version, processor/model provenance, and evidence references.

This means OpenBot/GrokBot/P/Hermes can be swapped or compared without losing the semantic continuity of the product.

## Provenance for agent actions

Every write should record, where applicable:

- workspace
- principal
- credential reference
- actor
- executor
- client/interface
- correlation_id
- command_id
- evidence/source references

Example:

```text
principal = user:serhii
actor = human:serhii
executor = agent:chatgpt
client = mcp:chatgpt
```

Example:

```text
principal = service:grok-scout
actor = agent:grok-scout
executor = agent:grok-scout
client = mcp:grok-bot
```

Example external processor result:

```text
actor = system:lmx
executor = agent:hermes-worker
client = adapter:hermes
inputs = [observation_...]
processor_version = ...
```

This makes multiple autonomous or semi-autonomous agents safe to audit and compare.

## Authorization

Tool-level permissions should distinguish read, submit evidence, annotate, enrich, assess, update application workflow, prepare interviews, perform identity-resolution operations, and administer the workspace.

Agent identity alone should never imply unrestricted write access.

Identity-resolution operations such as merge, unlink, relink and merge-revert should use stricter permissions than ordinary annotation.

## Idempotency

MCP and HTTP callers must supply or receive stable request/command identifiers for writes. Retries must not duplicate events or application actions.

External processor invocation should also use stable job/invocation identifiers so retries can be distinguished from genuinely new analyses.
