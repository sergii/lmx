# Personal CRM

Personal CRM owns candidate-specific opportunity workflow. It references canonical Candidate and JobOpening identities through public package contracts and never uses personal state as market state.

## Phase 1 public contract

`PersonalCrm::Api` exposes:

- `save_opening` - mark an opening as saved for a Candidate.
- `ignore_opening` - mark an opening as ignored for a Candidate.
- `start_application` - create a new Application attempt. Repeated attempts for the same Candidate and JobOpening are allowed.
- `fetch_opening_context` - read the current disposition and application attempts for an opening.

Save and ignore are a mutable personal projection backed by immutable domain events. Starting an application automatically makes the opening saved so an ignored opening cannot remain contradictory while an active application exists.

A new application starts in `applying` with `Submit application` as its next action. A later slice owns explicit submission, stage transitions, next-action editing, and Kanban projections.

All command mutations enter the Platform transactional Inbox, append domain events and Outbox messages atomically with their Personal CRM projection changes, and retain web/API/agent provenance.
