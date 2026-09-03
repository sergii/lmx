# Source catalog and acquisition planning

## Purpose

`config/sources.yml` is the canonical catalog of places where opportunities may exist. It is not a snapshot of the user's current career target and it is not limited to sources that already have a collector.

A source can remain in the catalog for years while the active search moves from Ruby/Rails to Go, Rust, AI engineering, Forward Deployed Engineering, or another role. Search intent belongs in `config/profiles/`.

The planning relationship is:

```text
Source Catalog + Search Profile -> Acquisition Plan
```

The catalog describes objective source facts. The profile describes what the user wants now. The planner combines them without rewriting source identity.

## Source dimensions

### `kind`

`kind` describes what the source objectively is, not who it is useful for:

- `job_board`
- `aggregator`
- `recruiting_marketplace`
- `company_career`
- `community`
- `social`

Do not encode specialization into `kind`. For example, Remote OK is a `job_board`, not a `remote_job_board`; a Ruby-only board is a `job_board`, not a `specialized_job_board`.

### `coverage`

`coverage` describes an objective specialization or constraint of the source.

Supported dimensions are:

- `domains`
- `technologies`
- `roles`
- `industries`
- `work_modes`

`scope: general` means the source is not known to target one narrow specialization. `scope: focused` means one or more coverage dimensions intentionally narrow the source.

Examples:

```yaml
kind: job_board
coverage:
  scope: general
```

```yaml
kind: job_board
coverage:
  scope: focused
  technologies: [ruby, rails]
  work_modes: [remote]
```

Coverage is evidence about the source, not a claim that every posting matches every listed value. Absence of a dimension means unknown or unconstrained; it must not be interpreted as a mismatch.

### `lifecycle`

Lifecycle describes catalog/support maturity independently from the acquisition transport:

- `discovered` - known source, not yet evaluated
- `evaluating` - feasibility or access is being investigated
- `supported` - an implementation exists but is not necessarily in the active unattended set
- `active` - supported and intended for normal acquisition
- `degraded` - supported but currently unreliable or restricted
- `retired` - no longer usable, but retained for historical identity and provenance

Do not delete a retired source merely because it is no longer useful. Historical observations and source identity must remain understandable.

`enabled` remains an operator kill switch. Lifecycle expresses semantic maturity; `enabled: false` prevents runtime use.

### `acquisition`

Acquisition entries describe how LMX can retrieve evidence from a source: RSS, HTTP API, HTML, browser, and their preference/status. They do not describe the user's job target.

Transport status and source lifecycle are intentionally separate. A source may be `evaluating` while several candidate transports are also `evaluate`, or `active` while one primary transport is active and fallbacks remain under evaluation.

## Search profile targets

The current career/search target belongs under `config/profiles/<profile>.yml`:

```yaml
targets:
  domains: [technology]
  technologies: [ruby, rails]
  roles: [software_engineer, backend_engineer]
```

Changing the target to Go or Rust changes the profile, not the source catalog:

```yaml
targets:
  domains: [technology]
  technologies: [go]
  roles: [software_engineer, backend_engineer]
```

Operational source query strings remain under `acquisition.source_queries`. They can differ from the durable target vocabulary because external search interfaces have source-specific syntax and quality characteristics.

## Planner compatibility rules

Source planning must be deterministic and explainable.

1. A source that is not enabled cannot be selected for runtime acquisition.
2. Only lifecycle `active` sources are selected for the normal unattended plan. Other lifecycle states remain visible in catalog/planning output.
3. General sources are compatible with any profile unless a future explicit restriction says otherwise.
4. For focused sources, compare only dimensions explicitly present in both `source.coverage` and `profile.targets`.
5. If an explicitly shared dimension has no intersection, that dimension is a compatibility mismatch.
6. A missing dimension on either side is unknown/unconstrained, not a mismatch.
7. Do not infer technology, role, industry, or work mode from the source name.
8. Source priority affects ranking/action policy; it must not override a hard explicit coverage mismatch.

Example:

```text
source technologies = [ruby, rails]
profile technologies = [go]
=> mismatch: technologies
```

```text
source work_modes = [remote]
profile has no work_modes target
=> compatible; profile did not express a conflict
```

This lets a Ruby-focused board remain in the catalog while automatically falling out of a Go-focused acquisition plan.

## Acquisition plan output

A planner should be able to expose, for every catalog source:

- source ID
- lifecycle status
- enabled state
- selected/not selected
- compatibility reasons or mismatch dimensions
- primary acquisition strategy
- configured operational queries

Planning is a read/decision layer. It does not mutate source metadata and it does not erase catalog entries that are irrelevant to the current profile.

## Boundary with ranking

Source selection and opportunity ranking are different decisions.

The source catalog answers: "where can relevant evidence exist?"
The search profile answers: "what am I looking for now?"
The acquisition plan answers: "which supported sources should run, and with which configured queries?"
Ranking answers: "which observed opportunities deserve attention?"

Keeping these boundaries separate prevents today's Ruby search from becoming permanent architecture.
