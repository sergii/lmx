# Personal CRM

Personal CRM owns candidate-specific opportunity workflow. It references canonical Candidate and JobOpening identities through public package contracts and never uses personal state as market state.

## Phase 1 public contract

`PersonalCrm::Api` exposes:

- `save_opening` - mark an opening as saved for a Candidate.
- `ignore_opening` - mark an opening as ignored for a Candidate.
- `start_application` - create a new Application attempt. Repeated attempts for the same Candidate and JobOpening are allowed.
- `advance_application` - append an application stage transition and update the read projection.
- `set_next_action` - append a next-action change and update the read projection.
- `fetch_opening_context` - reduce the current disposition and application attempts for one Candidate + JobOpening opportunity stream.
- `fetch_application` - read one projected application attempt.
- `search_applications` - query projected application attempts across opportunity streams.
- `application_stages` - return the canonical Personal CRM stage vocabulary.

Personal CRM workflow history is authoritative in immutable domain events. Save and ignore update the effective disposition by appending events to one opportunity stream for the Candidate + JobOpening pair. Starting an application automatically makes the opening saved so an ignored opening cannot remain contradictory while an active application exists.

Each Application attempt has its own stable `application_attempt` identity. Repeat applications for the same Candidate + JobOpening are valid. A new application starts in `applying` with `Submit application` as its next action.

## Event-authoritative workflow and projections

Opening Detail can reduce its single opportunity stream directly because the query is bounded to one Candidate + JobOpening pair.

Cross-opportunity list, table, and Kanban workflows use the package-owned `PersonalCrm::ApplicationProjection`. It is a rebuildable read model optimized for current stage, started/applied timestamps, channel, and next-action queries. It is not the system of record and must never manufacture domain events during rebuilds.

Current Phase 1 application stages are:

```text
applying
applied
recruiter_contact
screening
interview
offer
rejected
withdrawn
archived
```

All workflow command mutations enter the Platform transactional Inbox, append immutable domain events and Outbox messages, and retain web/API/agent provenance. Projection updates for accepted application workflow events happen synchronously inside the command transaction. The Event Store and Personal CRM projection table remain protected by the workspace PostgreSQL RLS boundary.
