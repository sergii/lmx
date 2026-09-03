import { Head, Link } from "@inertiajs/react"
import { CalendarDays, Clock3, ExternalLink } from "lucide-react"

import AppLayout from "@/layouts/app-layout"

type Meeting = {
  id: string
  kind: string
  status: "scheduled" | "completed" | "cancelled" | "no_show"
  sequence: number
  scheduled_at: string
  duration_minutes: number | null
  meeting_url: string | null
  candidate: { id: string; name: string; email: string | null }
  application: {
    id: string
    job: string
    project: string
    client: string
  } | null
}

const statusStyles: Record<Meeting["status"], string> = {
  scheduled: "bg-blue-50 text-blue-700 dark:bg-blue-950 dark:text-blue-300",
  completed:
    "bg-emerald-50 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300",
  cancelled: "bg-muted text-muted-foreground",
  no_show: "bg-amber-50 text-amber-700 dark:bg-amber-950 dark:text-amber-300",
}

export default function Meetings({ meetings }: { meetings: Meeting[] }) {
  const upcoming = meetings.filter((meeting) => meeting.status === "scheduled")
  const history = meetings.filter((meeting) => meeting.status !== "scheduled")

  return (
    <AppLayout breadcrumbs={[{ title: "Meetings", href: "/meetings" }]}>
      <Head title="Meetings" />
      <main className="max-w-6xl p-6">
        <div>
          <h1 className="text-xl font-semibold">Meetings</h1>
          <p className="text-muted-foreground mt-1 text-sm">
            Upcoming conversations and completed candidate interviews.
          </p>
        </div>

        {meetings.length === 0 ? (
          <EmptyMeetings />
        ) : (
          <div className="mt-8 space-y-8">
            <MeetingSection title="Upcoming" meetings={upcoming} />
            <MeetingSection title="History" meetings={history} />
          </div>
        )}
      </main>
    </AppLayout>
  )
}

function MeetingSection({
  title,
  meetings,
}: {
  title: string
  meetings: Meeting[]
}) {
  if (meetings.length === 0) return null

  return (
    <section>
      <h2 className="text-muted-foreground mb-3 text-sm font-medium">
        {title}
      </h2>
      <div className="overflow-hidden rounded-xl border">
        {meetings.map((meeting) => (
          <MeetingRow key={meeting.id} meeting={meeting} />
        ))}
      </div>
    </section>
  )
}

function MeetingRow({ meeting }: { meeting: Meeting }) {
  const date = new Date(meeting.scheduled_at)

  return (
    <div className="flex flex-wrap items-center gap-x-5 gap-y-3 border-b p-4 last:border-b-0">
      <div className="bg-muted flex size-9 shrink-0 items-center justify-center rounded-lg">
        <CalendarDays className="size-4" />
      </div>
      <div className="min-w-52 flex-1">
        <div className="font-medium capitalize">
          {meeting.kind.replaceAll("_", " ")}{" "}
          <span className="text-muted-foreground font-normal">
            #{meeting.sequence}
          </span>
        </div>
        <Link
          href={`/candidates/${meeting.candidate.id}`}
          className="text-muted-foreground hover:text-foreground text-sm"
        >
          {meeting.candidate.name}
        </Link>
        {meeting.application && (
          <p className="text-muted-foreground text-xs">
            {meeting.application.job} · {meeting.application.project} /{" "}
            {meeting.application.client}
          </p>
        )}
      </div>
      <div className="text-muted-foreground flex items-center gap-1 text-sm">
        <Clock3 className="size-4" />
        {date.toLocaleString([], { dateStyle: "medium", timeStyle: "short" })}
        {meeting.duration_minutes && ` · ${meeting.duration_minutes} min`}
      </div>
      <span
        className={`rounded-full px-2.5 py-1 text-xs font-medium capitalize ${statusStyles[meeting.status]}`}
      >
        {meeting.status.replaceAll("_", " ")}
      </span>
      {meeting.meeting_url && (
        <a
          href={meeting.meeting_url}
          target="_blank"
          rel="noreferrer"
          className="text-muted-foreground hover:text-foreground"
          aria-label="Open meeting link"
        >
          <ExternalLink className="size-4" />
        </a>
      )}
    </div>
  )
}

function EmptyMeetings() {
  return (
    <div className="mx-auto mt-20 max-w-sm text-center">
      <span className="bg-muted mx-auto flex size-16 items-center justify-center rounded-2xl">
        <CalendarDays className="text-muted-foreground size-7" />
      </span>
      <h2 className="mt-5 text-xl font-semibold">No meetings yet</h2>
      <p className="text-muted-foreground mt-2 text-sm">
        Schedule one from a candidate, job, or pipeline card to keep hiring
        conversations organized.
      </p>
    </div>
  )
}
