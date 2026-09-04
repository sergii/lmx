import { Head, router } from "@inertiajs/react"
import { format } from "date-fns"
import {
  Braces,
  History,
  RotateCcw,
  Save,
  ShieldCheck,
  UserRound,
} from "lucide-react"
import { useMemo, useState } from "react"

import Heading from "@/components/heading"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import AppLayout from "@/layouts/app-layout"
import { cn } from "@/lib/utils"

type JsonScalar = string | number | boolean | null

type JsonValue = JsonScalar | JsonValue[] | { [key: string]: JsonValue }

type ProfileData = Record<string, JsonValue>

interface CandidateSummary {
  id: string
  linked_user_id: string | null
  first_name: string | null
  last_name: string | null
  email: string | null
}

interface ProfileVersion {
  id: string
  candidate_id: string
  version_number: number
  schema_version: number
  profile: ProfileData
  content_digest: string
  origin: string
  accepted_by_user_id: string | null
  accepted_at: string | null
  evidence_ids: string[]
  created_at: string | null
}

interface Props {
  candidate: CandidateSummary | null
  latest_profile: ProfileVersion | null
  versions: ProfileVersion[]
}

function humanize(value: string) {
  return value.replaceAll("_", " ")
}

function dateTime(value: string | null) {
  return value ? format(new Date(value), "MMM d, yyyy · HH:mm") : "Unknown"
}

function originLabel(origin: string) {
  if (origin === "agent_accepted") return "Agent accepted"
  return humanize(origin)
}

function candidateName(candidate: CandidateSummary) {
  const name = [candidate.first_name, candidate.last_name]
    .filter(Boolean)
    .join(" ")
  if (name.length > 0) return name

  return candidate.email ?? "Candidate"
}

function isScalar(value: JsonValue): value is JsonScalar {
  return (
    value === null ||
    typeof value === "string" ||
    typeof value === "number" ||
    typeof value === "boolean"
  )
}

function scalarText(value: JsonScalar) {
  if (value === null) return "null"
  if (typeof value === "boolean") return value ? "Yes" : "No"
  return String(value)
}

function ProfileValue({ value }: { value: JsonValue }) {
  if (Array.isArray(value) && value.every(isScalar)) {
    if (value.length === 0) {
      return <span className="text-muted-foreground text-sm">Empty</span>
    }

    return (
      <div className="flex flex-wrap gap-1.5">
        {value.map((item, index) => (
          <Badge key={`${scalarText(item)}-${index}`} variant="secondary">
            {scalarText(item)}
          </Badge>
        ))}
      </div>
    )
  }

  if (isScalar(value)) {
    return <p className="text-sm leading-6">{scalarText(value)}</p>
  }

  return (
    <pre className="bg-muted/40 max-h-72 overflow-auto rounded-lg border p-3 text-xs leading-5">
      {JSON.stringify(value, null, 2)}
    </pre>
  )
}

function ProfileSnapshot({ version }: { version: ProfileVersion }) {
  const entries = Object.entries(version.profile)

  return (
    <section className="bg-card rounded-xl border">
      <div className="flex flex-col gap-3 border-b p-5 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="font-semibold">Profile snapshot</h2>
            <Badge variant="outline">v{version.version_number}</Badge>
            <Badge variant="secondary">{originLabel(version.origin)}</Badge>
          </div>
          <p className="text-muted-foreground mt-1 text-sm">
            Created {dateTime(version.created_at)} · schema v
            {version.schema_version}
          </p>
        </div>
        <div className="text-muted-foreground text-xs sm:text-right">
          <p>{version.evidence_ids.length} evidence references</p>
          <p className="font-mono">{version.content_digest.slice(0, 12)}…</p>
        </div>
      </div>

      {entries.length > 0 ? (
        <div className="grid gap-0 md:grid-cols-2">
          {entries.map(([key, value]) => (
            <div
              key={key}
              className="border-b p-5 last:border-b-0 md:border-r md:[&:nth-child(2n)]:border-r-0 md:[&:nth-last-child(-n+2)]:border-b-0"
            >
              <p className="text-muted-foreground mb-2 text-xs font-medium tracking-wide uppercase">
                {humanize(key)}
              </p>
              <ProfileValue value={value} />
            </div>
          ))}
        </div>
      ) : (
        <p className="text-muted-foreground p-5 text-sm">
          This canonical profile snapshot is empty.
        </p>
      )}
    </section>
  )
}

export default function ProfileShow({
  candidate,
  latest_profile,
  versions,
}: Props) {
  const [selectedVersionId, setSelectedVersionId] = useState(
    latest_profile?.id ?? null,
  )
  const selectedVersion = useMemo(
    () =>
      versions.find((version) => version.id === selectedVersionId) ??
      latest_profile,
    [latest_profile, selectedVersionId, versions],
  )
  const [editor, setEditor] = useState(
    JSON.stringify(latest_profile?.profile ?? {}, null, 2),
  )
  const [parseError, setParseError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  function loadSnapshotDraft(version: ProfileVersion) {
    setEditor(JSON.stringify(version.profile, null, 2))
    setParseError(null)
  }

  function resetEditor() {
    setEditor(JSON.stringify(latest_profile?.profile ?? {}, null, 2))
    setParseError(null)
  }

  function saveVersion() {
    let profile: unknown

    try {
      profile = JSON.parse(editor)
    } catch {
      setParseError("Profile must be valid JSON.")
      return
    }

    if (!profile || Array.isArray(profile) || typeof profile !== "object") {
      setParseError("Profile must be a JSON object.")
      return
    }

    setParseError(null)
    router.patch(
      "/profile",
      { profile: profile as ProfileData },
      {
        preserveScroll: true,
        onStart: () => setSaving(true),
        onFinish: () => setSaving(false),
      },
    )
  }

  if (!candidate) {
    return (
      <AppLayout breadcrumbs={[{ title: "Profile", href: "/profile" }]}>
        <Head title="Profile" />
        <div className="flex h-full flex-1 flex-col p-4 md:p-6">
          <Heading
            title="Profile"
            description="Your canonical candidate identity and versioned professional profile."
          />
          <div className="mt-6 rounded-xl border border-dashed p-8 text-center">
            <UserRound className="text-muted-foreground mx-auto size-8" />
            <h2 className="mt-3 font-semibold">No linked candidate yet</h2>
            <p className="text-muted-foreground mx-auto mt-1 max-w-lg text-sm">
              This workspace does not have a canonical Candidate linked to your
              user account yet.
            </p>
          </div>
        </div>
      </AppLayout>
    )
  }

  return (
    <AppLayout breadcrumbs={[{ title: "Profile", href: "/profile" }]}>
      <Head title="Profile" />
      <div className="flex h-full flex-1 flex-col gap-6 p-4 md:p-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
          <Heading
            title={candidateName(candidate)}
            description="Canonical candidate profile used for reproducible matching and opportunity decisions."
          />
          <div className="flex flex-wrap items-center gap-2">
            <Badge variant="outline" className="gap-1.5">
              <ShieldCheck className="size-3.5" />
              Canonical
            </Badge>
            {latest_profile && (
              <Badge>Latest v{latest_profile.version_number}</Badge>
            )}
          </div>
        </div>

        <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_22rem]">
          <div className="space-y-6">
            {selectedVersion ? (
              <ProfileSnapshot version={selectedVersion} />
            ) : (
              <section className="rounded-xl border border-dashed p-6">
                <p className="text-muted-foreground text-sm">
                  No canonical profile version exists yet.
                </p>
              </section>
            )}

            <section className="bg-card rounded-xl border">
              <div className="flex flex-col gap-3 border-b p-5 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <div className="flex items-center gap-2">
                    <Braces className="text-muted-foreground size-4" />
                    <h2 className="font-semibold">Create a new version</h2>
                  </div>
                  <p className="text-muted-foreground mt-1 max-w-2xl text-sm">
                    Edit the canonical JSON snapshot. Saving appends a new
                    immutable version and never changes prior versions.
                  </p>
                </div>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={resetEditor}
                >
                  <RotateCcw className="size-4" />
                  Reset
                </Button>
              </div>
              <div className="p-5">
                <textarea
                  aria-label="Canonical profile JSON"
                  value={editor}
                  onChange={(event) => setEditor(event.target.value)}
                  spellCheck={false}
                  className={cn(
                    "border-input bg-background min-h-80 w-full resize-y rounded-lg border p-4 font-mono text-sm leading-6 outline-none",
                    "focus-visible:ring-ring focus-visible:ring-2",
                    parseError && "border-destructive",
                  )}
                />
                <div className="mt-3 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                  <p
                    className={cn(
                      "text-muted-foreground text-sm",
                      parseError && "text-destructive",
                    )}
                  >
                    {parseError ??
                      "Top-level JSON remains flexible while the canonical profile schema evolves."}
                  </p>
                  <Button type="button" disabled={saving} onClick={saveVersion}>
                    <Save className="size-4" />
                    {saving ? "Saving..." : "Save new version"}
                  </Button>
                </div>
              </div>
            </section>
          </div>

          <aside className="bg-card h-fit rounded-xl border xl:sticky xl:top-6">
            <div className="flex items-center gap-2 border-b p-4">
              <History className="text-muted-foreground size-4" />
              <h2 className="font-semibold">Version history</h2>
              <Badge variant="secondary" className="ml-auto">
                {versions.length}
              </Badge>
            </div>
            <div className="max-h-[42rem] space-y-1 overflow-y-auto p-2">
              {versions.map((version) => {
                const selected = selectedVersion?.id === version.id
                const latest = latest_profile?.id === version.id

                return (
                  <div
                    key={version.id}
                    className={cn(
                      "hover:bg-muted/60 rounded-lg transition-colors",
                      selected && "bg-muted",
                    )}
                  >
                    <button
                      type="button"
                      onClick={() => setSelectedVersionId(version.id)}
                      className="w-full p-3 pb-2 text-left"
                    >
                      <div className="flex items-center gap-2">
                        <span className="font-medium">
                          v{version.version_number}
                        </span>
                        {latest && <Badge variant="outline">Latest</Badge>}
                        <span className="text-muted-foreground ml-auto text-xs">
                          {originLabel(version.origin)}
                        </span>
                      </div>
                      <p className="text-muted-foreground mt-1 text-xs">
                        {dateTime(version.created_at)}
                      </p>
                    </button>
                    <div className="flex items-center justify-between gap-2 px-3 pb-3">
                      <span className="text-muted-foreground font-mono text-[11px]">
                        {version.content_digest.slice(0, 10)}…
                      </span>
                      <button
                        type="button"
                        onClick={() => loadSnapshotDraft(version)}
                        className="text-primary text-xs font-medium hover:underline"
                      >
                        Use as draft
                      </button>
                    </div>
                  </div>
                )
              })}
              {versions.length === 0 && (
                <p className="text-muted-foreground p-3 text-sm">
                  No versions yet.
                </p>
              )}
            </div>
          </aside>
        </div>
      </div>
    </AppLayout>
  )
}
