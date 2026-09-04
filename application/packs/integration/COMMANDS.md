# Integration command boundary

State-changing agent/API operations use versioned command contracts and never call bounded-context persistence directly.

Current production-shaped write contracts are:

- `matches.assess.v1` - capability `assess:matches`
- `openings.submit.v1` - capability `submit:openings`

```text
MCP / HTTP ingress
      |
      v
Integration::Command::Context
      |
      v
server-side credential capability authorization
      |
      v
Workspace::Api.with_workspace
      |
      v
Platform Transactional Inbox
      |
      v
Platform::Reliability::CommandExecutor
      |
      v
owning bounded-context public API
      |
      +--> canonical state
      +--> Domain Event
      +--> Transactional Outbox
      |
      v
reconstructable command result
```

`command_id`, `idempotency_key`, message identity, principal/credential, actor/executor, interface/client, correlation and causation metadata are transport/application metadata. They are not accepted as part of command payloads.

Authorization happens before Workspace entry and before Inbox receipt. A caller without the contract's required capability therefore cannot create an Inbox record or invoke the owning bounded context.

The Inbox stores the normalized command payload and its digest. Reusing the same command/idempotency identity with a different payload returns `idempotency_conflict`.

`Platform::Reliability::CommandExecutor` holds the Inbox row lock around the owning application command and result persistence. The bounded-context state change, Domain Event, Outbox append, and successful Inbox result participate in one outer database transaction. A retry after success returns the prior result without creating duplicate canonical state or events.

## Match assessment

`matches.assess` records supplied analysis output; it does not invent a scoring formula. The assessment remains tied to an exact CandidateProfileVersion, opening evidence cutoff/snapshot, scoring-policy version, processor/version, optional model/version, evidence references, and generated time.

The resulting assessment is immediately readable through `matches.get.v1`.

## Opening submission

`openings.submit` accepts either a URL-backed vacancy or a no-URL opportunity such as a recruiter message. It routes through `MarketCatalog::Api.submit_opening`, preserving canonical URL identity and the actual ingress interface supplied by the trusted command context.

The command does not accept provenance fields in its tool arguments. MCP provenance remains `interface = mcp`; the Market Catalog record/event stores `ingress_interface = mcp` rather than pretending the submission came from `web/manual`.

A repeated command identity replays from the Integration Inbox. A distinct command carrying the same canonical vacancy URL reuses the existing JobPosting/JobOpening and records another submission event without duplicating market identity.

The existing browser/manual path remains supported by `MarketCatalog::Api.submit_manual_opening`. It keeps `web/manual` as the fine-grained ingress label while delegating canonical mutation to the same generic Market Catalog submission service.
