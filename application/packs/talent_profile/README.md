# Talent Profile

Talent Profile owns the workspace-scoped representation of a person in the talent domain. A `Candidate` is deliberately distinct from an authenticated `User`; `candidates.linked_user_id` is optional and is constrained to a membership in the same workspace.

## Phase 0 model

- `TalentProfile::Candidate` is a strangler model over the donor `candidates` table. It intentionally does not carry recruiting workflow associations.
- `TalentProfile::CandidateProfileVersion` is an append-only canonical profile snapshot with a monotonic version number, schema version and SHA-256 content digest. Future matching code can reference its TypeID to reproduce the exact profile used.
- `TalentProfile::CandidateEvidence` is append-only candidate-scoped evidence: a claim plus source type/reference, confidence, observed time and extensible provenance metadata.
- `candidate_profile_version_evidences` records exactly which evidence supports a canonical profile version.

The profile snapshot remains JSONB in Phase 0 so experience, skills, competencies, projects, achievements, education, preferences, constraints, goals, public profiles, resumes and narrative can evolve without prematurely creating a table per concept.

## Canonical truth and AI

A profile version is canonical once created. Allowed origins are `manual`, `import` and `agent_accepted`. There is deliberately no `ai_suggested` canonical origin. Agent-derived data can become a profile version only through the explicit `agent_accepted` path, which requires the accepting User TypeID and records `accepted_at`.

Raw observations and agent suggestions belong outside this canonical snapshot until accepted. Acquisition `SourceObservation` can be referenced from evidence through `source_type`/`source_reference` without a cross-package ActiveRecord dependency.

## Donor salvage

- **KEEP**: UUIDv7 storage, TypeIDs, explicit `WorkspaceContext`, RLS, and the distinction between raw evidence and an assessment/conclusion.
- **ADAPT**: donor `Evidence`'s `claim + source_type + source_reference + confidence` becomes generic `CandidateEvidence` with provenance, no Interview dependency.
- **ADAPT**: donor assessment `ai_suggested/manual/final` concept becomes a stricter publication boundary. AI suggestions are not profile versions; only explicitly accepted agent output can be canonical.
- **REPLACE**: legacy `Candidate` staffing associations and flat profile fields are not the new Talent Profile API. The table is shared temporarily for strangler compatibility.
- **REJECT for this context**: `SourcingBrief` is job/search strategy state. Its must-have/preference ideas may inform future candidate preferences, but the model does not belong in Talent Profile.

## Public API

Other packages should use only `TalentProfile::Api` for Phase 0 operations:

- `create_candidate`
- `record_evidence`
- `create_profile_version`
- `fetch_candidate`
- `fetch_latest_profile` - latest canonical `CandidateProfileVersion` for a Candidate
- `fetch_profile_version` - one exact historical profile version

The API accepts and returns TypeIDs and immutable snapshots rather than package-private ActiveRecord models. Latest-profile lookup remains distinct from exact historical-version lookup so callers can choose current convenience or reproducible provenance explicitly.
