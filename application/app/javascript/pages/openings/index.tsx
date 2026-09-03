import { Head, Link } from "@inertiajs/react"
import { formatDistanceToNowStrict } from "date-fns"
import { ArrowUpRight, Inbox, Search, Sparkles } from "lucide-react"

import Heading from "@/components/heading"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import AppLayout from "@/layouts/app-layout"

interface Source {
  key: string
  url: string | null
}

interface Opening {
  id: string
  title: string
  company: string | null
  lifecycle_state: string
  sources: Source[]
  first_seen_at: string | null
  last_seen_at: string | null
  signals: string[]
  compensation: string | null
  location: string | null
  remote_policy: string | null
  opportunity_score: number | null
  action_priority: number | null
  recommendation: string | null
}

interface Candidate {
  id: string
  name: string
  profile_version_id: string | null
  profile_version_number: number | null
}

interface Props {
  openings: Opening[]
  filters: {
    query: string | null
    lifecycle_state: string | null
    source_key: string | null
  }
  lifecycle_states: string[]
  candidate: Candidate | null
  summary: {
    visible_count: number
    assessed_count: number
    reopened_count: number
    source_count: number
  }
}

const sourceLabels: Record<string, string> = {
  dou: "DOU",
  djinni: "Djinni",
  work_ua: "Work.ua",
  robota_ua: "Robota.ua",
  remoteok: "RemoteOK",
  remote_rails: "Remote Rails",
  ruby_on_rails_jobs: "RubyOnRailsJobs",
}

function humanize(value: string) {
  return value.replaceAll("_", " ")
}

function sourceLabel(value: string) {
  return sourceLabels[value] ?? humanize(value)
}

function relativeTime(value: string | null) {
  if (!value) return "Unknown"

  return formatDistanceToNowStrict(new Date(value), { addSuffix: true })
}

function score(value: number | null) {
  return value == null ? "-" : Math.round(value).toString()
}

function lifecycleVariant(state: string) {
  if (state === "closed") return "secondary" as const
  if (state === "missing" || state === "probably_closed") {
    return "outline" as const
  }
  return "default" as const
}

function StatCard({ label, value }: { label: string; value: number }) {
  return (
    <div className="bg-card rounded-xl border px-4 py-3">
      <div className="text-muted-foreground text-xs font-medium tracking-wide uppercase">
        {label}
      </div>
      <div className="mt-1 text-2xl font-semibold tabular-nums">{value}</div>
    </div>
  )
}

export default function OpeningsIndex({
  openings,
  filters,
  lifecycle_states,
  candidate,
  summary,
}: Props) {
  const hasFilters = [
    filters.query,
    filters.lifecycle_state,
    filters.source_key,
  ].some(Boolean)

  return (
    <AppLayout breadcrumbs={[{ title: "Openings", href: "/openings" }]}>
      <Head title="Openings" />

      <div className="space-y-6 p-6">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
          <Heading
            title="Openings Inbox"
            description="Canonical market opportunities, cross-source evidence, and your latest match assessment."
          />
          <div className="text-muted-foreground max-w-md text-sm lg:text-right">
            {candidate ? (
              <span>
                Matching against{" "}
                <strong className="text-foreground">{candidate.name}</strong>
                {candidate.profile_version_number
                  ? ` · profile v${candidate.profile_version_number}`
                  : ""}
              </span>
            ) : (
              <span>
                No canonical Candidate is linked to your user yet. Openings are
                still visible; match scores will appear after a profile is
                linked.
              </span>
            )}
          </div>
        </div>

        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          <StatCard label="Visible" value={summary.visible_count} />
          <StatCard label="Assessed" value={summary.assessed_count} />
          <StatCard label="Reopened" value={summary.reopened_count} />
          <StatCard label="Sources" value={summary.source_count} />
        </div>

        <form
          action="/openings"
          method="get"
          className="bg-card grid gap-3 rounded-xl border p-4 lg:grid-cols-[minmax(240px,1fr)_180px_180px_auto]"
        >
          <div className="relative">
            <Search className="text-muted-foreground pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2" />
            <Input
              name="q"
              defaultValue={filters.query ?? ""}
              className="pl-9"
              placeholder="Search title"
              aria-label="Search openings"
            />
          </div>

          <select
            name="state"
            defaultValue={filters.lifecycle_state ?? ""}
            className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
            aria-label="Lifecycle state"
          >
            <option value="">All states</option>
            {lifecycle_states.map((state) => (
              <option key={state} value={state}>
                {humanize(state)}
              </option>
            ))}
          </select>

          <Input
            name="source"
            defaultValue={filters.source_key ?? ""}
            placeholder="Source, e.g. dou"
            aria-label="Source key"
          />

          <div className="flex gap-2">
            <Button type="submit">Filter</Button>
            {hasFilters && (
              <Button asChild type="button" variant="outline">
                <Link href="/openings">Clear</Link>
              </Button>
            )}
          </div>
        </form>

        {openings.length === 0 ? (
          <div className="flex min-h-64 flex-col items-center justify-center rounded-xl border border-dashed px-6 text-center">
            <Inbox className="text-muted-foreground mb-4 size-8" />
            <h2 className="text-lg font-semibold">No openings in this view</h2>
            <p className="text-muted-foreground mt-1 max-w-md text-sm">
              The canonical catalog has no openings matching these filters yet.
              This view will fill automatically as acquisition and
              reconciliation persist market evidence.
            </p>
          </div>
        ) : (
          <div className="bg-card overflow-hidden rounded-xl border">
            <div className="overflow-x-auto">
              <table className="w-full min-w-[1080px] text-sm">
                <thead className="bg-muted/40 text-muted-foreground border-b text-left text-xs font-medium tracking-wide uppercase">
                  <tr>
                    <th className="px-4 py-3">Opening</th>
                    <th className="px-4 py-3">Evidence</th>
                    <th className="px-4 py-3">Location</th>
                    <th className="px-4 py-3">Compensation</th>
                    <th className="px-4 py-3 text-right">Score</th>
                    <th className="px-4 py-3 text-right">Priority</th>
                    <th className="px-4 py-3">Seen</th>
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {openings.map((opening) => (
                    <tr
                      key={opening.id}
                      className="hover:bg-muted/20 align-top"
                    >
                      <td className="px-4 py-4">
                        <div className="flex max-w-md flex-wrap items-center gap-2">
                          <Link
                            href={`/openings/${opening.id}`}
                            className="font-semibold hover:underline"
                          >
                            {opening.title}
                          </Link>
                          <Badge
                            variant={lifecycleVariant(opening.lifecycle_state)}
                          >
                            {humanize(opening.lifecycle_state)}
                          </Badge>
                          {opening.signals.map((signal) => (
                            <Badge key={signal} variant="outline">
                              {signal === "new" && (
                                <Sparkles className="size-3" />
                              )}
                              {signal}
                            </Badge>
                          ))}
                        </div>
                        <div className="text-muted-foreground mt-1">
                          {opening.company ?? "Unknown company"}
                        </div>
                        {opening.recommendation && (
                          <p className="text-muted-foreground mt-2 max-w-md text-xs leading-relaxed">
                            {opening.recommendation}
                          </p>
                        )}
                      </td>

                      <td className="px-4 py-4">
                        <div className="flex max-w-56 flex-wrap gap-1.5">
                          {opening.sources.length === 0 ? (
                            <span className="text-muted-foreground">
                              No linked posting
                            </span>
                          ) : (
                            opening.sources.map((source) =>
                              source.url ? (
                                <Badge
                                  key={source.key}
                                  variant="outline"
                                  asChild
                                >
                                  <a
                                    href={source.url}
                                    target="_blank"
                                    rel="noreferrer"
                                  >
                                    {sourceLabel(source.key)}
                                    <ArrowUpRight className="size-3" />
                                  </a>
                                </Badge>
                              ) : (
                                <Badge key={source.key} variant="outline">
                                  {sourceLabel(source.key)}
                                </Badge>
                              ),
                            )
                          )}
                        </div>
                      </td>

                      <td className="px-4 py-4">
                        <div>{opening.location ?? "Unknown"}</div>
                        {opening.remote_policy && (
                          <div className="text-muted-foreground mt-1 text-xs">
                            {opening.remote_policy}
                          </div>
                        )}
                      </td>

                      <td className="px-4 py-4">
                        {opening.compensation ?? (
                          <span className="text-muted-foreground">Unknown</span>
                        )}
                      </td>

                      <td className="px-4 py-4 text-right font-semibold tabular-nums">
                        {score(opening.opportunity_score)}
                      </td>

                      <td className="px-4 py-4 text-right font-semibold tabular-nums">
                        {score(opening.action_priority)}
                      </td>

                      <td className="text-muted-foreground px-4 py-4 text-xs whitespace-nowrap">
                        <div>First {relativeTime(opening.first_seen_at)}</div>
                        <div className="mt-1">
                          Last {relativeTime(opening.last_seen_at)}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {summary.visible_count === 100 && (
          <p className="text-muted-foreground text-xs">
            Showing the newest 100 matching canonical openings. Cursor
            pagination is the next UI increment once the inbox needs more than
            the first working set.
          </p>
        )}
      </div>
    </AppLayout>
  )
}
