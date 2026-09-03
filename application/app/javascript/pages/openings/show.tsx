import { Head, Link, router } from "@inertiajs/react"
import { format, formatDistanceToNowStrict } from "date-fns"
import {
  ArrowLeft,
  ArrowUpRight,
  Ban,
  Bookmark,
  Database,
  History,
  Send,
  Sparkles,
} from "lucide-react"
import { useState, type ReactNode } from "react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import AppLayout from "@/layouts/app-layout"

interface Company {
  id: string
  name: string
  website_url: string | null
  primary_domain: string | null
  metadata: unknown
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
  metadata: unknown
  posting_count: number
  snapshot_count: number
}

interface Party {
  id: string
  role: string
  label: string | null
  confidence: number
  company: Company | null
  evidence: unknown
  metadata: unknown
}

interface Snapshot {
  id: string
  source_observation_id: string
  observed_at: string | null
  presence_state: string
  facts: unknown
  content_digest: string
  normalizer_key: string
  normalizer_version: string
  metadata: unknown
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
  first_seen_at: string | null
  last_confirmed_present_at: string | null
  missing_since: string | null
  metadata: unknown
  changed: boolean
  history: Snapshot[]
}

interface Candidate {
  id: string
  name: string
  profile_version_number: number | null
}

interface Assessment {
  id: string
  version_number: number
  opportunity_score: number | null
  action_priority: number | null
  score_details: unknown
  strengths: unknown[]
  gaps: unknown[]
  risks: unknown[]
  recommendation: string | null
  interview_angles: unknown[]
  evidence_references: unknown[]
  scoring_policy_version: string
  processor: unknown
  candidate_profile_version_id: string
  opening_evidence_cutoff: string | null
  opening_snapshot: unknown
  generated_at: string | null
  stale: boolean
  stale_reasons: string[]
}

interface OpeningDisposition {
  id: string
  state: "saved" | "ignored"
  decided_at: string | null
}

interface ApplicationAttempt {
  id: string
  via_posting_id: string | null
  stage: string
  started_at: string | null
  applied_at: string | null
  channel: string | null
  next_action: string | null
  next_action_at: string | null
}

interface PersonalCrmContext {
  disposition: OpeningDisposition | null
  applications: ApplicationAttempt[]
}

interface Props {
  opening: Opening
  company: Company | null
  parties: Party[]
  postings: Posting[]
  candidate: Candidate | null
  assessment: Assessment | null
  personal_crm: PersonalCrmContext | null
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
  return value ? format(new Date(value), "MMM d, yyyy · HH:mm") : "Unknown"
}

function relativeTime(value: string | null) {
  return value
    ? formatDistanceToNowStrict(new Date(value), { addSuffix: true })
    : "Unknown"
}

function lifecycleVariant(state: string) {
  if (state === "closed") return "secondary" as const
  if (state === "missing" || state === "probably_closed")
    return "outline" as const
  return "default" as const
}

function displayValue(value: unknown) {
  if (value == null) return "Unknown"
  if (typeof value === "string") return value
  if (typeof value === "number" || typeof value === "boolean")
    return String(value)
  return JSON.stringify(value) ?? "Unknown"
}

function Metric({
  label,
  value,
  note,
}: {
  label: string
  value: string | number
  note?: string
}) {
  return (
    <div className="bg-card border px-4 py-4">
      <div className="text-muted-foreground text-xs font-medium tracking-wide uppercase">
        {label}
      </div>
      <div className="mt-1 text-2xl font-semibold tabular-nums">{value}</div>
      {note && <div className="text-muted-foreground mt-1 text-xs">{note}</div>}
    </div>
  )
}

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="grid gap-1 border-b py-3 last:border-b-0 sm:grid-cols-[150px_1fr] sm:gap-4">
      <div className="text-muted-foreground text-xs font-medium tracking-wide uppercase">
        {label}
      </div>
      <div className="min-w-0 text-sm">{children}</div>
    </div>
  )
}

function JsonDetails({ label, value }: { label: string; value: unknown }) {
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

function Insight({ title, items }: { title: string; items: unknown[] }) {
  return (
    <div className="border p-4">
      <div className="text-xs font-semibold tracking-wide uppercase">
        {title}
      </div>
      {items.length === 0 ? (
        <p className="text-muted-foreground mt-3 text-sm">None recorded.</p>
      ) : (
        <ul className="mt-3 space-y-2 text-sm">
          {items.map((item, index) => (
            <li key={`${title}-${index}`}>{displayValue(item)}</li>
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
  personal_crm,
}: Props) {
  const [pendingAction, setPendingAction] = useState<string | null>(null)
  const dispositionState = personal_crm?.disposition?.state ?? null
  const applications = personal_crm?.applications ?? []
  const latestApplication = applications[0] ?? null

  function performAction(kind: "save" | "ignore" | "apply") {
    setPendingAction(kind)
    router.post(
      `/openings/${opening.id}/actions`,
      { kind, idempotency_key: crypto.randomUUID() },
      {
        preserveScroll: true,
        onFinish: () => setPendingAction(null),
      },
    )
  }

  return (
    <AppLayout
      breadcrumbs={[
        { title: "Openings", href: "/openings" },
        { title: opening.title, href: `/openings/${opening.id}` },
      ]}
    >
      <Head title={opening.title} />

      <div className="space-y-6 p-6">
        <header className="flex flex-col gap-5 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <Button asChild variant="ghost" size="sm" className="mb-3 -ml-3">
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
            <div className="text-muted-foreground mt-2 flex flex-wrap gap-x-3 gap-y-1 text-sm">
              <span>{company?.name ?? "Unknown company"}</span>
              {opening.location && <span>{opening.location}</span>}
              {opening.remote_policy && <span>{opening.remote_policy}</span>}
            </div>
          </div>

          <div className="flex flex-wrap gap-2">
            {candidate && (
              <>
                <Button
                  type="button"
                  variant={dispositionState === "saved" ? "secondary" : "outline"}
                  disabled={pendingAction !== null}
                  onClick={() => performAction("save")}
                >
                  <Bookmark className="size-4" />
                  {pendingAction === "save"
                    ? "Saving..."
                    : dispositionState === "saved"
                      ? "Saved"
                      : "Save"}
                </Button>
                <Button
                  type="button"
                  variant={dispositionState === "ignored" ? "secondary" : "outline"}
                  disabled={pendingAction !== null}
                  onClick={() => performAction("ignore")}
                >
                  <Ban className="size-4" />
                  {pendingAction === "ignore"
                    ? "Ignoring..."
                    : dispositionState === "ignored"
                      ? "Ignored"
                      : "Ignore"}
                </Button>
                <Button
                  type="button"
                  disabled={pendingAction !== null}
                  onClick={() => performAction("apply")}
                >
                  <Send className="size-4" />
                  {pendingAction === "apply"
                    ? "Starting..."
                    : applications.length > 0
                      ? "Apply again"
                      : "Apply"}
                </Button>
              </>
            )}
            {company?.website_url && (
              <Button asChild variant="outline">
                <a href={company.website_url} target="_blank" rel="noreferrer">
                  Company site
                  <ArrowUpRight className="size-4" />
                </a>
              </Button>
            )}
          </div>
        </header>

        <div className="bg-border grid gap-px overflow-hidden border sm:grid-cols-2 xl:grid-cols-4">
          <Metric
            label="Opportunity score"
            value={score(assessment?.opportunity_score ?? null)}
            note={
              assessment
                ? `Assessment v${assessment.version_number}`
                : "Not assessed"
            }
          />
          <Metric
            label="Action priority"
            value={score(assessment?.action_priority ?? null)}
            note={assessment?.stale ? "Assessment may need refresh" : undefined}
          />
          <Metric label="Sources" value={opening.posting_count} />
          <Metric label="Evidence snapshots" value={opening.snapshot_count} />
        </div>

        <div className="grid gap-6 xl:grid-cols-[minmax(0,2fr)_minmax(300px,1fr)]">
          <section className="bg-card border p-5">
            <div className="flex items-center gap-2">
              <Database className="size-4" />
              <h2 className="font-semibold">Canonical opening</h2>
            </div>
            <div className="mt-4">
              <Row label="Company">{company?.name ?? "Unknown company"}</Row>
              <Row label="Compensation">
                {opening.compensation ?? "Unknown"}
              </Row>
              <Row label="Location">{opening.location ?? "Unknown"}</Row>
              <Row label="Remote policy">
                {opening.remote_policy ?? "Unknown"}
              </Row>
              <Row label="First seen">{dateTime(opening.first_seen_at)}</Row>
              <Row label="Last seen">{dateTime(opening.last_seen_at)}</Row>
              {opening.closed_at && (
                <Row label="Closed">{dateTime(opening.closed_at)}</Row>
              )}
            </div>
            <JsonDetails label="Canonical metadata" value={opening.metadata} />
          </section>

          <section className="bg-card border p-5">
            <h2 className="font-semibold">Personal context</h2>
            {candidate ? (
              <div className="mt-4">
                <Row label="Candidate">{candidate.name}</Row>
                <Row label="Current profile">
                  {candidate.profile_version_number
                    ? `v${candidate.profile_version_number}`
                    : "No profile version"}
                </Row>
                <Row label="Personal state">
                  {dispositionState ? humanize(dispositionState) : "Not triaged"}
                </Row>
                <Row label="Applications">{applications.length}</Row>
                {latestApplication && (
                  <>
                    <Row label="Latest attempt">
                      {humanize(latestApplication.stage)} · started{" "}
                      {relativeTime(latestApplication.started_at)}
                    </Row>
                    <Row label="Next action">
                      {latestApplication.next_action ?? "None"}
                    </Row>
                  </>
                )}
                <Row label="Assessment">
                  {assessment
                    ? `v${assessment.version_number}`
                    : "Not assessed"}
                </Row>
                {assessment?.stale && (
                  <Row label="Needs refresh">
                    {assessment.stale_reasons.join(", ")}
                  </Row>
                )}
              </div>
            ) : (
              <p className="text-muted-foreground mt-4 text-sm">
                No canonical Candidate is linked to this user yet.
              </p>
            )}
          </section>
        </div>

        {candidate && (
          <section className="space-y-4">
            <div>
              <h2 className="font-semibold">Application attempts</h2>
              <p className="text-muted-foreground mt-1 text-sm">
                Each attempt is independent, so applying again later keeps the earlier history intact.
              </p>
            </div>
            {applications.length === 0 ? (
              <div className="text-muted-foreground border border-dashed p-6 text-sm">
                No application attempt has been started for this opening.
              </div>
            ) : (
              <div className="grid gap-3 lg:grid-cols-2">
                {applications.map((application) => (
                  <div key={application.id} className="bg-card border p-4">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <Badge variant="outline">{humanize(application.stage)}</Badge>
                      <span className="text-muted-foreground text-xs">
                        {relativeTime(application.started_at)}
                      </span>
                    </div>
                    <div className="mt-3 text-sm">
                      <span className="text-muted-foreground">Next action: </span>
                      {application.next_action ?? "None"}
                    </div>
                    {application.next_action_at && (
                      <div className="text-muted-foreground mt-1 text-xs">
                        Due {dateTime(application.next_action_at)}
                      </div>
                    )}
                    <div className="text-muted-foreground mt-3 text-xs break-all">
                      {application.id}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </section>
        )}

        <section className="space-y-4">
          <div>
            <div className="flex items-center gap-2">
              <Sparkles className="size-4" />
              <h2 className="font-semibold">Latest match assessment</h2>
            </div>
            {assessment?.generated_at && (
              <p className="text-muted-foreground mt-1 text-sm">
                Generated {relativeTime(assessment.generated_at)}
              </p>
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
                <Insight title="Strengths" items={assessment.strengths} />
                <Insight title="Gaps" items={assessment.gaps} />
                <Insight title="Risks" items={assessment.risks} />
              </div>
              <div className="mt-3">
                <Insight
                  title="Interview angles"
                  items={assessment.interview_angles}
                />
              </div>
              <div className="mt-5 grid gap-3 lg:grid-cols-2">
                <div className="border p-4 text-sm">
                  <Row label="Profile version">
                    {assessment.candidate_profile_version_id}
                  </Row>
                  <Row label="Evidence cutoff">
                    {dateTime(assessment.opening_evidence_cutoff)}
                  </Row>
                  <Row label="Scoring policy">
                    {assessment.scoring_policy_version}
                  </Row>
                  <JsonDetails label="Processor" value={assessment.processor} />
                </div>
                <div className="border p-4 text-sm">
                  <div className="text-xs font-semibold tracking-wide uppercase">
                    Evidence references
                  </div>
                  {assessment.evidence_references.length === 0 ? (
                    <p className="text-muted-foreground mt-3">None recorded.</p>
                  ) : (
                    <ul className="mt-3 space-y-2 break-all">
                      {assessment.evidence_references.map(
                        (reference, index) => (
                          <li key={`evidence-${index}`}>
                            {displayValue(reference)}
                          </li>
                        ),
                      )}
                    </ul>
                  )}
                  <JsonDetails
                    label="Opening snapshot used"
                    value={assessment.opening_snapshot}
                  />
                  <JsonDetails
                    label="Score details"
                    value={assessment.score_details}
                  />
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
          <div className="flex items-center gap-2">
            <History className="size-4" />
            <h2 className="font-semibold">Cross-source evidence</h2>
          </div>
          {postings.length === 0 ? (
            <div className="text-muted-foreground border border-dashed p-6 text-sm">
              This opening has no linked postings yet.
            </div>
          ) : (
            <div className="space-y-4">
              {postings.map((posting) => {
                const sourceUrl =
                  posting.canonical_url ?? posting.application_url
                return (
                  <article key={posting.id} className="bg-card border">
                    <div className="flex flex-col gap-4 border-b p-5 lg:flex-row lg:justify-between">
                      <div>
                        <div className="flex flex-wrap items-center gap-2">
                          <Badge variant="outline">
                            {sourceLabel(posting.source_key)}
                          </Badge>
                          <Badge
                            variant={lifecycleVariant(posting.lifecycle_state)}
                          >
                            {humanize(posting.lifecycle_state)}
                          </Badge>
                          {posting.changed && (
                            <Badge variant="outline">changed</Badge>
                          )}
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
                    <div className="bg-border grid gap-px sm:grid-cols-2 lg:grid-cols-4">
                      <Metric
                        label="First seen"
                        value={relativeTime(posting.first_seen_at)}
                      />
                      <Metric
                        label="Last present"
                        value={relativeTime(posting.last_confirmed_present_at)}
                      />
                      <Metric
                        label="Snapshots"
                        value={posting.history.length}
                      />
                      <Metric
                        label="Missing since"
                        value={
                          posting.missing_since
                            ? relativeTime(posting.missing_since)
                            : "-"
                        }
                      />
                    </div>
                    <div className="space-y-3 p-5">
                      {posting.history.map((snapshot) => (
                        <div key={snapshot.id} className="border p-4">
                          <div className="flex flex-wrap items-center justify-between gap-2">
                            <div className="flex flex-wrap items-center gap-2">
                              <Badge variant="outline">
                                {humanize(snapshot.presence_state)}
                              </Badge>
                              <span className="text-sm font-medium">
                                {dateTime(snapshot.observed_at)}
                              </span>
                            </div>
                            <span className="text-muted-foreground text-xs">
                              {snapshot.normalizer_key}@
                              {snapshot.normalizer_version}
                            </span>
                          </div>
                          <div className="text-muted-foreground mt-2 text-xs break-all">
                            Observation {snapshot.source_observation_id}
                          </div>
                          <div className="text-muted-foreground mt-1 text-xs break-all">
                            Digest {snapshot.content_digest}
                          </div>
                          <JsonDetails
                            label="Normalized facts"
                            value={snapshot.facts}
                          />
                          <JsonDetails
                            label="Snapshot metadata"
                            value={snapshot.metadata}
                          />
                        </div>
                      ))}
                      {posting.history.length === 0 && (
                        <p className="text-muted-foreground text-sm">
                          No snapshots recorded yet.
                        </p>
                      )}
                      <JsonDetails
                        label="Posting metadata"
                        value={posting.metadata}
                      />
                    </div>
                  </article>
                )
              })}
            </div>
          )}
        </section>

        <section className="space-y-4">
          <h2 className="font-semibold">Opening parties</h2>
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
                  <p className="text-muted-foreground mt-2 text-xs">
                    Confidence {Math.round(party.confidence * 100)}%
                  </p>
                  <div className="mt-4">
                    <JsonDetails label="Evidence" value={party.evidence} />
                    <JsonDetails
                      label="Party metadata"
                      value={party.metadata}
                    />
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
