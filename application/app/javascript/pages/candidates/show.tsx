import { Form, Head, Link } from "@inertiajs/react"
import {
  CalendarPlus,
  Clock3,
  Code2,
  ExternalLink,
  LinkIcon,
} from "lucide-react"
import { useState } from "react"

import Heading from "@/components/heading"
import LanguageProficiencyBadge from "@/components/language-proficiency-badge"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import AppLayout from "@/layouts/app-layout"

type Proficiency = {
  value: string
  code: string
  label: string
  full_label: string
} | null
type Candidate = {
  id: string
  first_name: string
  last_name: string
  email: string | null
  location: string | null
  time_zone: string | null
  source: string | null
  consent_status: string
  linkedin_url: string | null
  github_url: string | null
  english_proficiency: Proficiency
  salary_expectation: string | null
  availability: string | null
  notice_period: string | null
  work_authorization: string | null
  skills: string[]
  tags: string[]
  notes: string | null
}
type Application = {
  id: string
  stage: string
  job: string
  project: string
  client: string
}
type Meeting = {
  id: string
  kind: string
  status: string
  sequence: number
  scheduled_at: string
  duration_minutes: number | null
  meeting_url: string | null
  notes: string | null
  interview_id: string | null
  application: {
    id: string
    job: string
    project: string
    client: string
  } | null
}

export default function CandidateProfile({
  candidate,
  applications,
  meetings,
  meetingKinds,
  selectedApplicationId,
  openMeetingComposer,
}: {
  candidate: Candidate
  applications: Application[]
  meetings: Meeting[]
  meetingKinds: string[]
  selectedApplicationId?: string
  openMeetingComposer: boolean
}) {
  const [composerOpen, setComposerOpen] = useState(openMeetingComposer)
  const details = [
    ["Email", candidate.email],
    ["Location", candidate.location],
    ["Time zone", candidate.time_zone],
    ["Availability", candidate.availability],
    ["Notice period", candidate.notice_period],
    ["Work authorization", candidate.work_authorization],
    ["Source", candidate.source],
    ["Consent", candidate.consent_status],
  ]

  return (
    <AppLayout
      breadcrumbs={[
        { title: "Candidates", href: "/candidates" },
        {
          title: `${candidate.first_name} ${candidate.last_name}`,
          href: `/candidates/${candidate.id}`,
        },
      ]}
    >
      <Head title={`${candidate.first_name} ${candidate.last_name}`} />
      <div className="max-w-4xl p-6">
        <div className="mb-6 flex flex-wrap justify-between gap-4">
          <Heading
            title={`${candidate.first_name} ${candidate.last_name}`}
            description="Internal candidate profile, applications, and meeting history."
          />
          <div className="flex gap-2">
            <ScheduleMeetingDialog
              candidate={candidate}
              applications={applications}
              meetingKinds={meetingKinds}
              selectedApplicationId={selectedApplicationId}
              open={composerOpen}
              onOpenChange={setComposerOpen}
            />
            <Button asChild variant="outline">
              <Link href={`/candidates/${candidate.id}/edit`}>
                Edit profile
              </Link>
            </Button>
          </div>
        </div>
        <div className="grid gap-6 md:grid-cols-2">
          <section className="rounded-xl border p-5">
            <h2 className="mb-4 font-semibold">Profile</h2>
            <dl className="space-y-3">
              {details.map(([label, value]) => (
                <div key={label}>
                  <dt className="text-muted-foreground text-xs">{label}</dt>
                  <dd>{value || "—"}</dd>
                </div>
              ))}
              <div>
                <dt className="text-muted-foreground text-xs">
                  English proficiency
                </dt>
                <dd className="mt-1">
                  {candidate.english_proficiency ? (
                    <LanguageProficiencyBadge
                      code={candidate.english_proficiency.code}
                      label={candidate.english_proficiency.label}
                    />
                  ) : (
                    "—"
                  )}
                </dd>
              </div>
            </dl>
          </section>
          <section className="rounded-xl border p-5">
            <h2 className="mb-4 font-semibold">Skills & links</h2>
            <p className="mb-4">
              {candidate.skills.length
                ? candidate.skills.join(", ")
                : "No skills recorded"}
            </p>
            <ProfileLinks candidate={candidate} />
            <h3 className="mt-5 font-medium">Notes</h3>
            <p className="text-muted-foreground mt-1 text-sm whitespace-pre-wrap">
              {candidate.notes || "No notes"}
            </p>
          </section>
        </div>
        <MeetingTimeline candidate={candidate} meetings={meetings} />
        <section className="mt-6 rounded-xl border p-5">
          <h2 className="mb-4 font-semibold">Applications</h2>
          {applications.length === 0 ? (
            <p className="text-muted-foreground">No active applications.</p>
          ) : (
            <div className="space-y-2">
              {applications.map((application) => (
                <Link
                  key={application.id}
                  href="/jobs"
                  className="hover:bg-muted/50 block rounded-lg border p-3"
                >
                  <span className="font-medium">{application.job}</span>
                  <span className="text-muted-foreground">
                    {" "}
                    · {application.project} / {application.client} ·{" "}
                    {application.stage.replaceAll("_", " ")}
                  </span>
                </Link>
              ))}
            </div>
          )}
        </section>
      </div>
    </AppLayout>
  )
}

function ProfileLinks({ candidate }: { candidate: Candidate }) {
  if (!candidate.linkedin_url && !candidate.github_url) return null

  return (
    <div className="flex flex-wrap gap-2">
      {candidate.linkedin_url && (
        <a
          className="border-input hover:bg-muted inline-flex items-center gap-2 rounded-md border px-3 py-2 text-sm font-medium"
          href={candidate.linkedin_url}
          target="_blank"
          rel="noreferrer"
        >
          <LinkIcon className="size-4 text-[#0A66C2]" />
          View LinkedIn profile
          <ExternalLink className="text-muted-foreground size-3" />
        </a>
      )}
      {candidate.github_url && (
        <a
          className="border-input hover:bg-muted inline-flex items-center gap-2 rounded-md border px-3 py-2 text-sm font-medium"
          href={candidate.github_url}
          target="_blank"
          rel="noreferrer"
        >
          <Code2 className="size-4" />
          View GitHub profile
          <ExternalLink className="text-muted-foreground size-3" />
        </a>
      )}
    </div>
  )
}

function ScheduleMeetingDialog({
  candidate,
  applications,
  meetingKinds,
  selectedApplicationId,
  open,
  onOpenChange,
}: {
  candidate: Candidate
  applications: Application[]
  meetingKinds: string[]
  selectedApplicationId?: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogTrigger asChild>
        <Button>
          <CalendarPlus /> Schedule meeting
        </Button>
      </DialogTrigger>
      <DialogContent className="max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Schedule meeting</DialogTitle>
          <DialogDescription>
            Plan a conversation with {candidate.first_name}. Meetings can be
            general or tied to a specific role.
          </DialogDescription>
        </DialogHeader>
        <Form
          action="/meetings"
          method="post"
          onSuccess={() => onOpenChange(false)}
        >
          {({ processing, errors }) => (
            <FieldGroup>
              <input type="hidden" name="candidate_id" value={candidate.id} />
              <Field>
                <FieldLabel htmlFor="application_id">Role context</FieldLabel>
                <select
                  id="application_id"
                  name="application_id"
                  defaultValue={selectedApplicationId ?? ""}
                  className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
                >
                  <option value="">General candidate conversation</option>
                  {applications.map((application) => (
                    <option key={application.id} value={application.id}>
                      {application.job} · {application.project}
                    </option>
                  ))}
                </select>
              </Field>
              <Field>
                <FieldLabel htmlFor="kind">Meeting type</FieldLabel>
                <select
                  id="kind"
                  name="kind"
                  defaultValue="recruiter_screen"
                  className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
                >
                  {meetingKinds.map((kind) => (
                    <option key={kind} value={kind}>
                      {kind.replaceAll("_", " ")}
                    </option>
                  ))}
                </select>
                <FieldError
                  errors={errors.kind?.map((message) => ({ message }))}
                />
              </Field>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field>
                  <FieldLabel htmlFor="scheduled_at">When</FieldLabel>
                  <Input
                    id="scheduled_at"
                    name="scheduled_at"
                    type="datetime-local"
                    required
                  />
                  <FieldError
                    errors={errors.scheduled_at?.map((message) => ({
                      message,
                    }))}
                  />
                </Field>
                <Field>
                  <FieldLabel htmlFor="duration_minutes">Duration</FieldLabel>
                  <Input
                    id="duration_minutes"
                    name="duration_minutes"
                    type="number"
                    min="5"
                    step="5"
                    defaultValue="30"
                  />
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor="meeting_url">Meeting link</FieldLabel>
                <Input
                  id="meeting_url"
                  name="meeting_url"
                  type="url"
                  placeholder="https://meet.google.com/..."
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="notes">Notes</FieldLabel>
                <textarea
                  id="notes"
                  name="notes"
                  className="border-input min-h-24 w-full rounded-md border bg-transparent p-3 text-sm"
                  placeholder="Agenda, interviewer, or preparation notes"
                />
              </Field>
              <Button type="submit" disabled={processing}>
                Schedule meeting
              </Button>
            </FieldGroup>
          )}
        </Form>
      </DialogContent>
    </Dialog>
  )
}

function MeetingTimeline({
  candidate,
  meetings,
}: {
  candidate: Candidate
  meetings: Meeting[]
}) {
  const upcoming = meetings
    .filter(
      (meeting) =>
        meeting.status === "scheduled" &&
        new Date(meeting.scheduled_at) >= new Date(),
    )
    .sort(
      (a, b) =>
        new Date(a.scheduled_at).getTime() - new Date(b.scheduled_at).getTime(),
    )
  const history = meetings.filter((meeting) => !upcoming.includes(meeting))
  return (
    <section className="mt-6 rounded-xl border p-5">
      <div className="flex items-center gap-2">
        <Clock3 className="size-4" />
        <h2 className="font-semibold">Meetings & interviews</h2>
      </div>
      {meetings.length === 0 ? (
        <p className="text-muted-foreground mt-4 text-sm">
          No meetings yet. Schedule the first conversation from this profile.
        </p>
      ) : (
        <div className="mt-4 space-y-6">
          {upcoming.length > 0 && (
            <MeetingGroup
              candidate={candidate}
              title="Upcoming"
              meetings={upcoming}
            />
          )}
          {history.length > 0 && (
            <MeetingGroup
              candidate={candidate}
              title="History"
              meetings={history}
            />
          )}
        </div>
      )}
    </section>
  )
}

function MeetingGroup({
  candidate,
  title,
  meetings,
}: {
  candidate: Candidate
  title: string
  meetings: Meeting[]
}) {
  return (
    <div>
      <h3 className="text-muted-foreground text-xs font-semibold tracking-wide uppercase">
        {title}
      </h3>
      <div className="mt-2 space-y-2">
        {meetings.map((meeting) => (
          <article
            key={meeting.id}
            className="flex flex-col gap-3 rounded-lg border p-3 sm:flex-row sm:items-center sm:justify-between"
          >
            <div>
              <p className="font-medium capitalize">
                {meeting.kind.replaceAll("_", " ")}
                {meeting.sequence > 1 && ` #${meeting.sequence}`}
              </p>
              <p className="text-muted-foreground text-sm">
                {new Intl.DateTimeFormat(undefined, {
                  dateStyle: "medium",
                  timeStyle: "short",
                }).format(new Date(meeting.scheduled_at))}
                {meeting.duration_minutes &&
                  ` · ${meeting.duration_minutes} min`}
              </p>
              {meeting.application && (
                <p className="text-muted-foreground text-xs">
                  {meeting.application.job} · {meeting.application.project} /{" "}
                  {meeting.application.client}
                </p>
              )}
              {meeting.notes && (
                <p className="text-muted-foreground mt-1 text-sm">
                  {meeting.notes}
                </p>
              )}
            </div>
            <div className="flex items-center gap-2">
              {meeting.meeting_url && (
                <Button asChild size="sm" variant="outline">
                  <a
                    href={meeting.meeting_url}
                    target="_blank"
                    rel="noreferrer"
                  >
                    <ExternalLink /> Join
                  </a>
                </Button>
              )}
              {meeting.status === "scheduled" ? (
                <Form action={`/meetings/${meeting.id}`} method="patch">
                  {({ processing }) => (
                    <Button
                      type="submit"
                      name="status"
                      value="completed"
                      size="sm"
                      disabled={processing}
                    >
                      Complete
                    </Button>
                  )}
                </Form>
              ) : (
                <>
                  <span className="bg-muted rounded-full px-2 py-1 text-xs capitalize">
                    {meeting.status.replaceAll("_", " ")}
                  </span>
                  {meeting.status === "completed" &&
                    (meeting.interview_id ? (
                      <Button asChild size="sm" variant="outline">
                        <Link href={`/interviews/${meeting.interview_id}`}>
                          Open interview
                        </Link>
                      </Button>
                    ) : (
                      <Form action="/interviews" method="post">
                        <input
                          type="hidden"
                          name="candidate_id"
                          value={candidate.id}
                        />
                        <input
                          type="hidden"
                          name="meeting_id"
                          value={meeting.id}
                        />
                        {meeting.application && (
                          <input
                            type="hidden"
                            name="application_id"
                            value={meeting.application.id}
                          />
                        )}
                        <input type="hidden" name="status" value="completed" />
                        <input
                          type="hidden"
                          name="completed_at"
                          value={meeting.scheduled_at}
                        />
                        <Button type="submit" size="sm" variant="outline">
                          Record interview
                        </Button>
                      </Form>
                    ))}
                </>
              )}
            </div>
          </article>
        ))}
      </div>
    </div>
  )
}
