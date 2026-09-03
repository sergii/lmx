# Platform reliability foundation

Platform owns shared technical primitives with no business ownership. This slice provides the durable reliability boundary required before external write commands are exposed through HTTP, MCP, webhook, import, or other ingress adapters.

## Scope

Three workspace-scoped persistence concepts are provided:

- `platform_inbox_messages` - durable command receipt, idempotency identity, processing state, retry count, provenance, payload digest/reference, and prior result/error.
- `platform_domain_events` - immutable business-event envelopes with optimistic aggregate versioning and command/provenance/evidence metadata.
- `platform_outbox_messages` - integration-message delivery records appended in the same database transaction as their owning domain event.

All three tables enable and force PostgreSQL row-level security through the same `app.current_organization` workspace setting used by the rest of LMX. The committed `db/structure.sql` is generated from the reliability migration with the repository's PostgreSQL baseline rather than maintained as hand-written schema SQL.

## Public API

Other packages should use only `Platform::Reliability::Api`. The package-private ActiveRecord models are persistence details.

### Inbox

```ruby
received = Platform::Reliability::Api.receive_command(
  message_id: "delivery-opaque",
  command_id: "command-opaque",
  idempotency_key: "idempotency-opaque",
  command_name: "matches.assess",
  interface: "mcp",
  client: "chatgpt",
  principal: "user:serhii",
  credential: "credential:opaque",
  actor: "human:serhii",
  executor: "agent:chatgpt",
  payload: { candidate_id: "candidate_...", opening_id: "opening_..." }
)
```

`receive_command` is idempotent inside the current workspace. A retry with the same command/idempotency identity and payload returns the existing command snapshot, including a prior successful result. JSON object keys are canonicalized before hashing, so equivalent payload objects do not conflict merely because their key insertion order differs. Reusing that identity for different command semantics or payload raises `IdempotencyConflict`.

Processing transitions are explicit:

```text
received -> processing -> succeeded
                      \-> failed -> processing ...
```

`start_command` increments `attempt_count`. `complete_command` persists the reconstructable prior result. `fail_command` persists structured error data without discarding the original command payload metadata.

## Event Store and aggregate versions

`append_domain_event` accepts `expected_aggregate_version`. Platform takes a PostgreSQL advisory transaction lock for the workspace/aggregate pair, compares the expected version with the current durable version, and appends the next event only when they match. Stale writers receive `ConcurrencyConflict` rather than silently overwriting history.

A domain package remains responsible for its own business rules and state mutation. When domain state and event history must commit together, call `append_domain_event` inside the same outer ActiveRecord transaction as the owning state change; nested Rails transactions join the same database transaction by default.

Domain-event envelopes preserve the canonical provenance fields where applicable:

- workspace
- event type/version
- aggregate type/id/version
- occurred/effective time
- principal and credential reference
- actor and executor
- interface/client
- evidence references
- correlation and causation IDs
- command ID and idempotency key
- event data

Events are append-only at the model boundary.

## Transactional Outbox

`append_domain_event(..., outbox_messages: [...])` creates the event and its Outbox records in one transaction. The Outbox contains versioned integration-message payloads, not internal domain-event objects.

A future publisher can use:

- `claim_outbox` - claims due `pending`/`failed` rows with `FOR UPDATE SKIP LOCKED`, records a publishing lease, and increments attempts.
- `mark_outbox_published` - records successful publication and releases the lease.
- `mark_outbox_failed` - records structured failure, releases the lease, and sets the next retry time.

A row left in `publishing` because a worker crashed is reclaimable after the configured lease timeout. A live lease is not claimable by another worker, while a stale lease is claimed again with an incremented attempt count. This avoids permanently stranded Outbox records without requiring transport-specific recovery logic.

The publisher transport itself is intentionally outside this slice.

## Workspace boundary

The API requires an already-established database workspace scope. It does not resolve `Organization`, `Current`, `WorkspaceContext`, memberships, or authorization. Integration/domain composition must enter the workspace through the owning Workspace public API before calling Platform reliability operations.

This keeps dependency direction clean:

```text
Ingress / domain command composition
        |
        +--> Workspace::Api.with_workspace
        |
        +--> Platform::Reliability::Api
        |
        +--> owning bounded-context application service
```

Platform reads the already-established PostgreSQL workspace setting only to persist the correct tenant key and enforce fail-closed behavior.

## Deliberately not included

This foundation does **not** define:

- domain-specific commands or event types
- `matches.assess`, `postings.submit`, or Application writes
- authorization capabilities for writes
- an Integration command dispatcher
- queue/background-job transport
- Outbox destinations or publisher adapters
- event projections or replay orchestration
- a public integration-event catalog

Those pieces can now be added without inventing a second idempotency/event-delivery mechanism per bounded context.
