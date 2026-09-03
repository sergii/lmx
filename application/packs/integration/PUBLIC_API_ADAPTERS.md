# Public application API adapters

Integration query adapters consume narrow public application APIs from owning bounded contexts. They do not access another package's ActiveRecord models.

## Candidate read adapters

`Integration::Read::Adapters::CandidatesGet` implements `candidates.get.v1` through:

```ruby
fetch_candidate(candidate_id:)
```

`Integration::Read::Adapters::CandidateProfileGet` implements `candidates.profile.v1` through:

```ruby
fetch_latest_profile(candidate_id:)
```

`TalentProfile::Api` provides both operations and returns immutable snapshots with public typed identifiers. `candidates.profile.v1` means the latest canonical CandidateProfileVersion for the Candidate; it does not accept or infer a historical version ID. Exact historical-version lookup remains available inside the owning public API and can become a separate transport contract if needed.

Missing, invalid, or cross-workspace candidate/profile reads surface as `TalentProfile::Api::NotFound` rather than persistence exceptions. Both candidate operations require `read:candidates`.

The adapters remain dependency-injected and independently testable. Production composition supplies the owning package public API.

## Opening read adapters

`Integration::Read::Adapters::OpeningsSearch` and `Integration::Read::Adapters::OpeningsGet` consume an API with:

```ruby
search_openings(**attributes)
fetch_opening(opening_id:)
```

`attributes` is the normalized `openings.search.v1` input and may contain `query`, `filters`, `cursor`, and `limit`. Integration does not define Market Catalog filter fields; the generic `filters` object is passed through unchanged.

`opening_id` remains an opaque public identifier. Integration never parses it into an owning-package primary key.

`MarketCatalog::Api` provides this public read surface and exposes `MarketCatalog::Api::NotFound` for failed public resource lookup.

## MatchAssessment read adapter

`Integration::Read::Adapters::MatchesGet` implements `matches.get.v1` through the Intelligence public API:

```ruby
fetch_match_assessment(workspace_id:, assessment_id:)
```

The v1 contract is intentionally a resource lookup by opaque MatchAssessment identifier. Integration does not define or recalculate Opportunity Score, Action Priority, strengths, gaps, risks, recommendation, or provenance fields. Those fields remain owned by Intelligence and are passed through as its stable public snapshot.

The adapter enters the owning workspace scope before calling `Intelligence::Api` and passes the same opaque workspace identifier to the public operation. Missing or cross-workspace assessments are normalized from `Intelligence::Api::NotFound` to the Integration `not_found` outcome.

A future ranked/top-matches query should be a separate collection/query contract rather than overloading `matches.get.v1` with search semantics.

## Application read adapter

`Integration::Read::Adapters::ApplicationsGet` preserves the Integration-side contract expected from canonical Personal CRM:

```ruby
fetch_application(application_id:)
```

It is deliberately **not registered in the production read stack yet**.

The donor application's legacy `Application` model represents a staffing workflow tied to legacy `Job`, including a permanent candidate/job uniqueness constraint and staffing-specific stages. Canonical LMX defines `Application` as an application attempt against a canonical `JobOpening`, optionally through a `JobPosting`, with repeat attempts allowed. Publishing the legacy model behind a new facade would freeze the wrong domain semantics.

Canonical Personal CRM is Phase 1+ work. Until that bounded context owns the canonical model and public API, `applications.get.v1` remains a known contract with no registered implementation and returns stable `not_implemented`.

## Workspace execution scope

Owning package reads require explicit workspace and PostgreSQL tenant scope. `Integration::Read::Adapters::PublicApiWorkspaceScope` implements `Integration::Read::Ports::WorkspaceScope` through `Workspace::Api.with_workspace`.

The adapter passes `context.workspace_id` through unchanged. It never resolves `Organization`, manipulates `Current`, or sets PostgreSQL session state itself.

```ruby
workspace_scope.call(context) do
  candidate_api.fetch_latest_profile(candidate_id: query.input.fetch(:id))
end
```

Workspace owns tenant resolution, `Current` state, and PostgreSQL RLS setup/restoration.

## Authorization composition

`Integration::Read::CredentialCapabilityResolver` obtains capabilities only from a server-side credential source and constructs an identity-bound grant. Client input never supplies capability arrays.

`Integration::Read::CapabilityAuthorization` runs before query routing and therefore before entering Workspace scope.

## Concrete read stack

`Integration::ReadStack.build` is the public production-shaped composition entrypoint.

By default it composes:

- `Workspace::Api`
- `TalentProfile::Api`
- `MarketCatalog::Api`
- `Intelligence::Api`
- an injected server-side credential source
- `CredentialCapabilityResolver`
- `CapabilityAuthorization`
- `PublicApiWorkspaceScope`
- opening, candidate, candidate-profile, and MatchAssessment query adapters
- `QueryRouter`
- `Dispatcher`
- `Integration::Mcp::ReadAdapter`

The package therefore declares explicit dependencies on Workspace, Talent Profile, Market Catalog, and Intelligence. Cross-package references are limited to their public application APIs.

The public builder still accepts API objects as keyword arguments so tests or alternate compositions can substitute compatible implementations without changing query adapters.

```ruby
mcp_reads = Integration::ReadStack.build(
  credential_source: credential_source
)
```

The implemented production read paths are:

```text
MCP
 |
 v
CredentialCapabilityResolver
 |
 v
CapabilityAuthorization
 |
 v
QueryRouter
 |
 +--> openings.search / openings.get
 |      |
 |      +--> Workspace::Api.with_workspace
 |      |
 |      +--> MarketCatalog::Api
 |
 +--> candidates.get / candidates.profile
 |      |
 |      +--> Workspace::Api.with_workspace
 |      |
 |      +--> TalentProfile::Api
 |
 +--> matches.get
        |
        +--> Workspace::Api.with_workspace
        |
        +--> Intelligence::Api
```

`applications.get` is intentionally absent from the router until canonical Personal CRM exists.

## Not-found mapping

The low-level adapters accept `not_found_errors:` and normalize only configured owning-package lookup failures to `Integration::Read::Error::NotFound`. Unexpected exceptions are re-raised.

Concrete composition uses only public package errors: `Workspace::Api::NotFound`, `MarketCatalog::Api::NotFound`, `TalentProfile::Api::NotFound`, and `Intelligence::Api::NotFound`. ActiveRecord lookup exceptions do not cross owning-package application boundaries or appear in Integration composition.
