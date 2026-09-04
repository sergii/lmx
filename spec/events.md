# Commands, domain events, integration events, and telemetry

LMX separates four concepts that are often incorrectly mixed together.

## Commands

Commands represent intent. Examples:

```text
job_posting.submit
job_posting.update
job_posting.link_to_opening
job_posting.unlink_from_opening
job_opening.submit_manual
job_opening.merge
job_opening.revert_merge
personal_crm.save_opening
personal_crm.ignore_opening
personal_crm.start_application
personal_crm.advance_application
personal_crm.set_next_action
company.enrich
```

A command can be rejected by authentication, authorization, validation, idempotency, evidence policy, or domain rules.

## Domain events

Domain events represent accepted business facts. Examples:

```text
job_posting.discovered
job_posting.updated
job_posting.compensation_changed
job_posting.missing_observed
job_posting.probably_closed
job_posting.closed
job_posting.reappeared
job_posting.linked_to_opening
job_posting.unlinked_from_opening
job_opening.created
job_opening.manual_submission_recorded
job_opening.merged
job_opening.merge_reverted
job_opening.reopened
intelligence.match_assessment.recorded
personal_crm.opening.saved
personal_crm.opening.ignored
personal_crm.application.started
personal_crm.application.stage_changed
personal_crm.application.next_action_changed
company.enriched
```

Use past-tense facts for domain events. The distinction is intentional: `job_posting.update` is an instruction, while `job_posting.updated` is a fact. Personal CRM follows the same rule: `personal_crm.advance_application` is intent, while `personal_crm.application.stage_changed` is an accepted fact.

A manual opening submission is ingress, not an acquisition source. The accepted command may create a new JobOpening or attach another manually supplied URL to an already known JobPosting/JobOpening identity. The Event Store records that accepted fact without inventing a new market source called "manual".

A Personal CRM opportunity stream groups workflow facts for one Candidate + JobOpening pair. Individual application attempts inside that stream keep independent `application_attempt` identities, so repeat applications remain valid.

A source observation is not automatically a domain event. Evidence first enters the observation/reconciliation boundary.

## Integration events

Integration events are stable, versioned messages for consumers outside a bounded context. They may aggregate or redact internal domain details.

Examples:

```text
lmx.opportunity.high_priority.v1
lmx.posting.changed.v1
lmx.application.stage_changed.v1
delivery.telegram.opportunity
```

`intelligence.match_assessment.recorded` is the durable accepted assessment fact. A candidate-aware Telegram notification is a separate transactional Outbox message, `delivery.telegram.opportunity`, containing only the decision context needed by Delivery. Delivery may terminally suppress that transport message when its Action Priority is below the configured notification threshold; suppression does not remove or rewrite the underlying MatchAssessment or domain event.

Transport-specific delivery messages are not a second source of business truth. The generic assessment integration message remains independently available to non-Telegram consumers.

## Telemetry

Telemetry describes system behavior, not business truth. Examples include crawl latency, parser errors, MCP call duration, queue depth, and notification delivery latency.

Telemetry belongs in the observability stack, not the business Event Store.

## Audit and provenance

Audit views are projections over immutable domain events, observation references, and command metadata, not a separate mutable source of truth.

A useful audit entry can explain:

- what changed
- previous and new values when relevant
- which evidence supported the change
- who initiated the change
- who executed it
- which authenticated principal/credential was used
- which client/interface or adapter was used
- which command caused the event
- which earlier event or observation caused the command
- when it happened and when it became effective

## Principal, actor, executor, client

Keep these concepts separate when applicable:

- `principal` - authenticated security identity allowed to call the interface.
- `credential` - credential/token/key reference used by the principal.
- `actor` - logical initiator of the business intent.
- `executor` - component or agent that performed the action on behalf of the actor.
- `client` - interface/client implementation such as web, API, MCP, Grok Bot or ChatGPT.

Examples:

```text
principal: user:serhii
actor: human:serhii
executor: agent:chatgpt
client: mcp:chatgpt
```

```text
principal: service:grok-scout
actor: agent:grok-scout
executor: agent:grok-scout
client: mcp:grok-bot
```

```text
principal: system:acquisition
actor: crawler:dou
executor: parser:dou-v3
client: acquisition:http-html
```

This distinction is essential when many autonomous or semi-autonomous agents operate on behalf of humans or services.
