# Personal CRM

Personal CRM owns candidate-specific opportunity workflow. It references canonical Candidate and JobOpening identities through public package contracts and never uses personal state as market state.

## Phase 1 public contract

`PersonalCrm::Api` exposes:

- `save_opening` - mark an opening as saved for a Candidate.
- `ignore_opening` - mark an opening as ignored for a Candidate.
- `start_application` - create a new Application attempt. Repeated attempts for the same Candidate and JobOpening are allowed.
- `fetch_opening_context` - reduce the current disposition and application attempts for one Candidate + JobOpening opportunity stream.

Personal CRM workflow history is currently authoritative in immutable domain events. Save and ignore update the effective disposition by appending events to one opportunity stream for the Candidate + JobOpening pair. Starting an application automatically makes the opening saved so an ignored opening cannot remain contradictory while an active application exists.

A new application starts in `applying` with `Submit application` as its next action. Each attempt has its own stable `application_attempt` identity even though multiple attempts can live in the same opportunity stream.

Opening Detail can reduce its single opportunity stream directly. Broader list, table, and Kanban workflows may add package-owned rebuildable read projections when cross-opportunity queries require them; those projections are not the system of record.

All command mutations enter the Platform transactional Inbox, append immutable domain events and Outbox messages, and retain web/API/agent provenance. The Platform Event Store remains protected by the workspace RLS boundary.
