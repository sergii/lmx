# Integration command boundary

State-changing agent/API operations use versioned command contracts and never call bounded-context persistence directly.

The first production-shaped write contract is `matches.assess.v1`, requiring the server-side capability `assess:matches`.

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
Intelligence::Api.assess_match
      |
      +--> immutable MatchAssessment
      +--> Domain Event
      +--> Transactional Outbox
      |
      v
reconstructable command result
```

`command_id`, `idempotency_key`, message identity, principal/credential, actor/executor, interface/client, correlation and causation metadata are transport/application metadata. They are not accepted as part of the assessment payload.

Authorization happens before Workspace entry and before Inbox receipt. A caller without `assess:matches` therefore cannot create an Inbox record or invoke Intelligence.

The Inbox stores the normalized command payload and its digest. Reusing the same command/idempotency identity with a different payload returns `idempotency_conflict`.

`Platform::Reliability::CommandExecutor` holds the Inbox row lock around the owning application command and result persistence. The Intelligence state change, Domain Event, Outbox append, and successful Inbox result all participate in one outer database transaction. A retry after success returns the prior result without creating another MatchAssessment or event.

`matches.assess` records supplied analysis output; it does not invent a scoring formula. The assessment remains tied to an exact CandidateProfileVersion, opening evidence cutoff/snapshot, scoring-policy version, processor/version, optional model/version, evidence references, and generated time.

The resulting assessment is immediately readable through the existing `matches.get.v1` read contract.
