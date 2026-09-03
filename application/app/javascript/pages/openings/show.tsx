import { Head, Link } from "@inertiajs/react"
import { format, formatDistanceToNowStrict } from "date-fns"
import {
  ArrowLeft,
  ArrowUpRight,
  Database,
  History,
  Sparkles,
  UserRound,
} from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import AppLayout from "@/layouts/app-layout"

type JsonValue =
  | string
  | number
  | boolean
  | null
  | JsonValue[]
  | { [key: string]: JsonValue }

type JsonRecord = { [key: string]: JsonValue }

interface Company {
  id: string
  name: string
  website_url: string | null
  primary_domain: string | null
  metadata: JsonRecord
}

interface Opening {
  id: string
  title: string
  lifecycle_state: string
  first_seen_at: string | null
  last_seen_at: string | null
  closed_at: string | null
  location: string | null
  remote_policy: string | null
  compensation: string | null
  metadata: JsonRecord
  posting_count: number
  snapshot_count: number
}

interface Party {
  id: string
  role: string
  label: string | null
  confidence: number
  company: Company | null
  evidence: JsonValue
  metadata: JsonRecord
}

interface Snapshot {
  id: string
  source_observation_id: string
  observed_at: string | null
  presence_state: string
  title: string | null
  source_published_at: string | null
  source_updated_at: string | null
  facts: JsonRecord
  content_digest: string
  normalizer_key: string
  normalizer_version: string
  metadata: JsonRecord
  created_at: string | null
}

interface Posting {
  id: string
  source_key: string
  title: string
  lifecycle_state: string
  external_id: string | null
  canonical_url: string | null
  application_url: string | null
  publisher: Company | null
  source_published_at: string | null
  source_updated_at: string | null
  first_seen_at: string | null
  last_confirmed_present_at: string | null
  missing_since: string | null
  metadata: JsonRecord
  changed: boolean
  history: Snapshot[]
}

interface Candidate {
  id: string
  name: string
  profile_version_id: string | null
  profile_version_number: number | null
}

interface Assessment {
  id: string
  version_number: number
  opportunity_score: number | null
  action_priority: number | null
  score_details: JsonRecord
  strengths: JsonValue[]
  gaps: JsonValue[]
  risks: JsonValue[]
  recommendation: string | null
  interview_angles: JsonValue[]
  evidence_references: JsonValue[]
  scoring_policy_version: string
  processor: JsonRecord
  candidate_profile_version_id: string
  opening_evidence_cutoff: string | null
  opening_snapshot: JsonRecord
  generated_at: string | null
  created_at: string | null
  stale: boolean
  stale_reasons: string[]
}

interface Props {
  opening: Opening
  company: Company | null
  parties: Party[]
  postings: Posting[]
  candidate: Candidate | null
  assessment: Assessment | null
}

const sourceLabels: Record<string, string> = {
  dou: "DOU",
  djinni: "Djinni",
  work_ua: "Work.ua",
  robota_ua: "Robota.ua",
  jooble: "Jooble",
  remoteok: "RemoteOK",
  remote_rails: "Remote Rails",
  ruby_on_rails_jobs: "RubyOnRailsJobs",
  hacker_news: "Hacker News",
  linkedin: "LinkedIn",
  indeed: "Indeed",
  wellfound: "Wellfound",
  x: "X",
}

function humanize(value: string) {
  return value.replaceAll("_", " ")
}

function sourceLabel(value: string) {
  return sourceLabels[value] ?? humanize(value)
}

function score(value: number | null) {
  return value == null ? "-" : Math.round(value).toString()
}

function dateTime(value: string | null) {
  if (!value) return "Unknown"

  return format(new Date(value), "MMM d, yyyy · HH:mm")
}

function relativeTime(value: string | null) {
  if (!value) return "Unknown"

  return formatDistanceToNowStrict(new Date(value), { addSuffix: true })
}

function lifecycleVariant(state: string) {
  if (state === "closed") return "secondary" as const
  if (state === "missing" || state === "probably_closed") {
    return "outline" as const
  }
  return "default" as const
}

function displayValue(value: JsonValue) {
  if (value === null) return "Unknown"
  if (typeof value === "string") return value
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value)
  }
  return JSON.stringify(value)
}

function MetricCard({
  label,
  value,
  description,
}: {
  label: string
  value: string | number
  description?: string
}) {
  return (
    <div className="bg-card border px-4 py-4">
      <div className="text-muted-foreground text-xs font-medium tracking-wide uppercase">
        {label}
      </div>
      <div className="mt-1 text-2xl font-semibold tabular-nums">{value}</div>
      {description && (
        <div className="text-muted-foreground mt-1 text-xs">{description}</div>
      )}
    </div>
  )
}

function DetailRow({
  label,
  children,
}: {
  label: string
  children: React.ReactNode
}) {
  return (
    <div className="grid gap-1 border-b py-3 last:border-b-0 sm:grid-cols-[150px_1fr] sm:gap-4">
      <div className="text-muted-foreground text-xs font-medium tracking-wide uppercase">
        {label}
      </div>
      <div className="min-w-0 text-sm">{children}</div>
    </div>
  )
}

function JsonDetails({ label, value }: { label: string; value: JsonValue }) {
  return (
    <details className="border-t pt-3">
      <summary className="text-muted-foreground cursor-pointer text-xs font-medium tracking-wide uppercase">
        {label}
      </summary>
      <pre className="bg-muted/40 mt-3 overflow-x-auto p-3 text-xs leading-relaxed">
        {JSON.stringify(value, null, 2)}
      </pre>
    </details>
  )
}

function InsightList({
  title,
  items,
  emptyLabel,
}: {
  title: string
  items: JsonValue[]
  emptyLabel: string
}) {
  return (
    <div className="border p-4">
      <div className="text-xs font-semibold tracking-wide uppercase">{title}</div>
      {items.length === 0 ? (
        <p className="text-muted-foreground mt-3 text-sm">{emptyLabel}</p>
      ) : (
        <ul className="mt-3 space-y-2 text-sm">
          {items.map((item, index) => (
            <li key={`${title}-${index}`} className="leading-relaxed">
              {displayValue(item)}
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

export default function OpeningShow({
  opening,
  company,
  parties,
  postings,
  candidate,
  assessment,
}: Props) {
  return (
    <AppLayout
      breadcrumbs={[
        { title: "Openings", href: "/openings" },
        { title: opening.title, href: `/openings/${opening.id}` },
      ]}
    >
      <Head title={opening.title} />

      <div className="space-y-6 p-6">
        <div className="flex flex-col gap-5 lg:flex-row lg:items-start lg:justify-between">
          <div className="min-w-0">
            <Button asChild variant="ghost" size="sm" className="-ml-3 mb-3">
              <Link href="/openings">
                <ArrowLeft className="size-4" />
                Back to openings
              </Link>
            </Button>

            <div className="flex flex-wrap items-center gap-2">
              <h1 className="text-2xl font-semibold tracking-tight">
                {opening.title}
              </h1>
              <Badge variant={lifecycleVariant(opening.lifecycle_state)}>
                {humanize(opening.lifecycle_state)}
              </Badge>
            </div>

            <div className="text-muted-foreground mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm">
              <span>{company?.name ?? "Unknown company"}</span>
              {opening.location && <span>{opening.location}</span>}
              {opening.remote_policy && <span>{opening.remote_policy}</span>}
            </div>
          </div>

          {company?.website_url && (
            <Button asChild variant="outline">
              <a href={company.website_url} target="_blank" rel="noreferrer">
                Company site
                <ArrowUpRight className="size-4" />
              </a>
            </Button>
          )}
        </div>

        <div className="grid gap-px overflow-hidden border bg-border sm:grid-cols-2 xl:grid-cols-4">
          <MetricCard
            label="Opportunity score"
            value={score(assessment?.opportunity_score ?? null)}
            description={assessment ? `Assessment v${assessment.version_number}` : "Not assessed"}
          />
          <MetricCard
            label="Action priority"
            value={score(assessment?.action_priority ?? null)}
            description={assessment?.stale ? "Assessment may need refresh" : undefined}
          />
          <MetricCard label="Sources" value={opening.posting_count} />
          <MetricCard label="Evidence snapshots" value={opening.snapshot_count} />
        </div>

        <div className="grid gap-6 xl:grid-cols-[minmax(0,2fr)_minmax(300px,1fr)]">
          <section className="bg-card border p-5">
            <div className="flex items-center gap-2">
              <Database className="size-4" />
              <h2 className="font-semibold">Canonical opening</h2>
            </div>

            <div className="mt-4">
              <DetailRow label="Company">
                {company?.name ?? "Unknown company"}
                {company?.primary_domain && (
                  <span className="text-muted-foreground ml-2 text-xs">
                    {company.primary_domain}
                  </span>
                )}
              </DetailRow>
              <DetailRow label="Compensation">
                {opening.compensation ?? "Unknown"}
              </DetailRow>
              <DetailRow label="Location">{opening.location ?? "Unknown"}</DetailRow>
              <DetailRow label="Remote policy">
                {opening.remote_policy ?? "Unknown"}
              </DetailRow>
              <DetailRow label="First seen">
                {dateTime(opening.first_seen_at)}
              </DetailRow>
              <DetailRow label="Last seen">
                {dateTime(opening.last_seen_at)}
              </DetailRow>
              {opening.closed_at && (
                <DetailRow label="Closed">{dateTime(opening.closed_at)}</DetailRow>
              )}
            </div>

            <JsonDetails label="Canonical metadata" value={opening.metadata} />
          </section>

          <section className="bg-card border p-5">
            <div className="flex items-center gap-2">
              <UserRound className="size-4" />
              <h2 className="font-semibold">Personal context</h2>
            </div>

            {candidate ? (
              <div className="mt-4">
                <DetailRow label="Candidate">{candidate.name}</DetailRow>
                <DetailRow label="Current profile">
                  {candidate.profile_version_number
                    ? `v${candidate.profile_version_number}`
                    : "No profile version"}
                </DetailRow>
                <DetailRow label="Assessment">
                  {assessment ? (
                    <div className="flex flex-wrap items-center gap-2">
                      <span>v{assessment.version_number}</span>
                      <Badge variant={assessment.stale ? "outline" : "secondary"}>
                        {assessment.stale ? "Needs refresh" : "Current"}
                      </Badge>
                    </div>
                  ) : (
                    "Not assessed"
                  )}
                </DetailRow>
                {assessment?.stale && (
                  <DetailRow label="Why stale">
                    {assessment.stale_reasons.join(", ")}
                  </DetailRow>
                )}
              </div>
            ) : (
              <p className="text-muted-foreground mt-4 text-sm leading-relaxed">
                No canonical Candidate is linked to this user yet. Market evidence
                remains available without personal scoring.
              </p>
            )}
          </section>
        </div>

        <section className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <div className="flex items-center gap-2">
                <Sparkles className="size-4" />
                <h2 className="font-semibold">Latest match assessment</h2>
              </div>
              <p className="text-muted-foreground mt-1 text-sm">
                Versioned derived intelligence against an exact candidate profile
                and opening evidence cutoff.
              </p>
            </div>
            {assessment?.generated_at && (
              <div className="text-muted-foreground text-xs">
                Generated {relativeTime(assessment.generated_at)}
              </div>
            )}
          </div>

          {assessment ? (
            <div className="bg-card border p-5">
              {assessment.recommendation && (
                <p className="max-w-4xl text-sm leading-relaxed">
                  {assessment.recommendation}
                </p>
              )}

              <div className="mt-5 grid gap-3 lg:grid-cols-3">
                <InsightList
                  title="Strengths"
                  items={assessment.strengths}
                  emptyLabel="No strengths recorded."
                />
                <InsightList
                  title="Gaps"
                  items={assessment.gaps}
                  emptyLabel="No gaps recorded."
                />
                <InsightList
                  title="Risks"
                  items={assessment.risks}
                  emptyLabel="No risks recorded."
                />
              </div>

              <div className="mt-5">
                <InsightList
                  title="Interview angles"
                  items={assessment.interview_angles}
                  emptyLabel="No interview angles recorded."
                />
              </div>

              <div className="mt-5 grid gap-3 lg:grid-cols-2">
                <div className="border p-4 text-sm">
                  <div className="text-xs font-semibold tracking-wide uppercase">
                    Assessment provenance
                  </div>
                  <div className="mt-3 space-y-2">
                    <div>
                      <span className="text-muted-foreground">Profile version: </span>
                      {assessment.candidate_profile_version_id}
                    </div>
                    <div>
                      <span className="text-muted-foreground">Evidence cutoff: </span>
                      {dateTime(assessment.opening_evidence_cutoff)}
                    </div>
                    <div>
                      <span className="text-muted-foreground">Scoring policy: </span>
                      {assessment.scoring_policy_version}
                    </div>
                  </div>
                  <JsonDetails label="Processor" value={assessment.processor} />
                </div>

                <div className="border p-4 text-sm">
                  <div className="text-xs font-semibold tracking-wide uppercase">
                    Evidence references
                  </div>
                  {assessment.evidence_references.length === 0 ? (
                    <p className="text-muted-foreground mt-3">
                      No explicit evidence references recorded.
                    </p>
                  ) : (
                    <ul className="mt-3 space-y-2 break-all">
                      {assessment.evidence_references.map((reference, index) => (
                        <li key={`evidence-${index}`}>{displayValue(reference)}</li>
                      ))}
                    </ul>
                  )}
                  <JsonDetails
                    label="Opening snapshot used for assessment"
                    value={assessment.opening_snapshot}
                  />
                  <JsonDetails label="Score details" value={assessment.score_details} />
                </div>
              </div>
            </div>
          ) : (
            <div className="text-muted-foreground border border-dashed p-6 text-sm">
              No MatchAssessment exists for this candidate and opening yet.
            </div>
          )}
        </section>

        <section className="space-y-4">
          <div>
            <div className="flex items-center gap-2">
              <History className="size-4" />
              <h2 className="font-semibold">Cross-source evidence</h2>
            </div>
            <p className="text-muted-foreground mt-1 text-sm">
              Every source publication stays distinct while resolving to the same
              canonical hiring need.
            </p>
          </div>

          {postings.length === 0 ? (
            <div className="text-muted-foreground border border-dashed p-6 text-sm">
              This opening has no linked postings yet.
            </div>
          ) : (
            <div className="space-y-4">
              {postings.map((posting) => {
                const sourceUrl = posting.canonical_url ?? posting.application_url

                return (
                  <article key={posting.id} className="bg-card border">
                    <div className="flex flex-col gap-4 border-b p-5 lg:flex-row lg:items-start lg:justify-between">
                      <div>
                        <div className="flex flex-wrap items-center gap-2">
                          <Badge variant="outline">
                            {sourceLabel(posting.source_key)}
                          </Badge>
                          <Badge variant={lifecycleVariant(posting.lifecycle_state)}>
                            {humanize(posting.lifecycle_state)}
                          </Badge>
                          {posting.changed && <Badge variant="outline">changed</Badge>}
                        </div>
                        <h3 className="mt-3 font-semibold">{posting.title}</h3>
                        <div className="text-muted-foreground mt-1 text-sm">
                          {posting.publisher?.name ?? "Unknown publisher"}
                          {posting.external_id && ` · ${posting.external_id}`}
                        </div>
                      </div>

                      {sourceUrl && (
                        <Button asChild variant="outline" size="sm">
                          <a href={sourceUrl} target="_blank" rel="noreferrer">
                            Open source
                            <ArrowUpRight className="size-4" />
                          </a>
                        </Button>
                      )}
                    </div>

                    <div className="grid gap-px bg-border sm:grid-cols-2 lg:grid-cols-4">
                      <MetricCard
                        label="First seen"
                        value={relativeTime(posting.first_seen_at)}
                      />
                      <MetricCard
                        label="Last present"
                        value={relativeTime(posting.last_confirmed_present_at)}
                      />
                      <MetricCard label="Snapshots" value={posting.history.length} />
                      <MetricCard
                        label="Missing since"
                        value={posting.missing_since ? relativeTime(posting.missing_since) : "-"}
                      />
                    </div>

                    <div className="p-5">
                      {posting.history.length === 0 ? (
                        <p className="text-muted-foreground text-sm">
                          No normalized posting snapshots have been recorded yet.
                        </p>
                      ) : (
                        <div className="space-y-3">
                          {posting.history.map((snapshot) => (
                            <div key={snapshot.id} className="border p-4">
                              <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                                <div>
                                  <div className="flex flex-wrap items-center gap-2">
                                    <Badge variant="outline">
                                      {humanize(snapshot.presence_state)}
                                    </Badge>
                                    <span className="text-sm font-medium">
                                      {dateTime(snapshot.observed_at)}
                                    </span>
                                  </div>
                                  <div className="text-muted-foreground mt-2 break-all text-xs">
                                    Observation {snapshot.source_observation_id}
                                  </div>
                                </div>
                                <div className="text-muted-foreground text-xs">
                                  {snapshot.normalizer_key}@{snapshot.normalizer_version}
                                </div>
                              </div>

                              <div className="text-muted-foreground mt-3 text-xs break-all">
                                Digest {snapshot.content_digest}
                              </div>
                              <JsonDetails label="Normalized facts" value={snapshot.facts} />
                              <JsonDetails label="Snapshot metadata" value={snapshot.metadata} />
                            </div>
                          ))}
                        </div>
                      )}

                      <JsonDetails label="Posting metadata" value={posting.metadata} />
                    </div>
                  </article>
                )
              })}
            </div>
          )}
        </section>

        <section className="space-y-4">
          <div>
            <h2 className="font-semibold">Opening parties</h2>
            <p className="text-muted-foreground mt-1 text-sm">
              Employer, vendor, agency, end-client, and other company roles stay
              explicit instead of being collapsed into one publisher identity.
            </p>
          </div>

          {parties.length === 0 ? (
            <div className="text-muted-foreground border border-dashed p-6 text-sm">
              No opening parties have been resolved yet.
            </div>
          ) : (
            <div className="grid gap-3 lg:grid-cols-2">
              {parties.map((party) => (
                <div key={party.id} className="bg-card border p-5">
                  <div className="flex flex-wrap items-center gap-2">
                    <Badge variant="outline">{humanize(party.role)}</Badge>
                    <span className="font-semibold">
                      {party.company?.name ?? party.label ?? "Unknown party"}
                    </span>
                  </div>
                  <div className="text-muted-foreground mt-2 text-xs">
                    Confidence {Math.round(party.confidence * 100)}%
                  </div>
                  <div className="mt-4">
                    <JsonDetails label="Evidence" value={party.evidence} />
                    <JsonDetails label="Party metadata" value={party.metadata} />
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>
      </div>
    </AppLayout>
  )
}
