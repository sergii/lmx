# Personal CRM

Personal CRM owns candidate-specific opportunity workflow. It references canonical Candidate and JobOpening identities through public package APIs but never owns candidate profile history or market lifecycle.

The first canonical slice separates two concepts that must not be collapsed:

- `OpportunityDisposition` is the candidate-opening-level personal handling state. Saving or ignoring an opening changes this state and never creates an application attempt.
- `Application` is one concrete application attempt. The schema permits multiple attempts for the same candidate and opening; the initial web action records the first attempt idempotently, while an explicit reapply command can be added later.

`OpportunityDisposition` is a mutable projection backed by immutable domain events. `Application` attempts are durable records whose lifecycle changes must also be represented through domain events rather than history-destroying status rewrites.

Cross-context validation uses the public APIs of Talent Profile and Market Catalog. Personal CRM does not reach into their Active Record models.
