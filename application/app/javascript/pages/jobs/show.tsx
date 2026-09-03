import { Form, Head, Link } from "@inertiajs/react"
import { ExternalLink, FileText, Sparkles } from "lucide-react"

import Heading from "@/components/heading"
import { Button } from "@/components/ui/button"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import AppLayout from "@/layouts/app-layout"

type PipelineApplication = {
  id: string
  stage: string
  candidate: {
    id: string
    first_name: string
    last_name: string
    email: string | null
  }
}
type Job = {
  id: string
  title: string
  project: string
  client: string
  technology_stack: string | null
  seniority: string | null
  status: string
  description: string | null
}
type SourcingBrief = {
  id: string
  status: string
  summary: string | null
  must_haves: string[]
  nice_to_haves: string[]
  exclusions: string[]
  search_queries: string[]
  location_preferences: string[]
  language_requirement: string | null
  interview_focus: string | null
  approved_at: string | null
} | null
type Posting = {
  id: string
  channel: string
  status: string
  title: string | null
  public_url: string
  content_snapshot: string | null
  published_at: string | null
  closed_at: string | null
}

export default function JobPipeline({
  job,
  stages,
  applications,
  sourcingBrief,
  postings,
  postingChannels,
  postingStatuses,
  sourcingBriefStatuses,
}: {
  job: Job
  stages: string[]
  applications: PipelineApplication[]
  sourcingBrief: SourcingBrief
  postings: Posting[]
  postingChannels: string[]
  postingStatuses: string[]
  sourcingBriefStatuses: string[]
}) {
  return (
    <AppLayout
      breadcrumbs={[
        { title: "Jobs", href: "/jobs" },
        { title: job.title, href: `/jobs/${job.id}` },
      ]}
    >
      <Head title={job.title} />
      <main className="p-6">
        <div className="mb-6 flex flex-wrap justify-between gap-4">
          <Heading
            title={job.title}
            description={`${job.client} · ${job.project}${job.technology_stack ? ` · ${job.technology_stack}` : ""}`}
          />
          <Button asChild>
            <Link href={`/candidates/new?job_id=${job.id}`}>
              Source candidate
            </Link>
          </Button>
        </div>
        <div className="grid gap-6 xl:grid-cols-2">
          <RoleBrief job={job} />
          <SourcingBriefEditor
            job={job}
            sourcingBrief={sourcingBrief}
            statuses={sourcingBriefStatuses}
          />
        </div>
        <div className="mt-6 grid gap-6 xl:grid-cols-2">
          <JobPostings
            job={job}
            postings={postings}
            channels={postingChannels}
            statuses={postingStatuses}
          />
          <SourcingGuidance sourcingBrief={sourcingBrief} />
        </div>
        <section className="mt-6">
          <h2 className="mb-3 font-semibold">Candidate pipeline</h2>
          <div className="grid gap-4 xl:grid-cols-3">
            {stages.map((stage) => {
              const items = applications.filter(
                (application) => application.stage === stage,
              )
              return (
                <section
                  key={stage}
                  className="bg-muted/20 rounded-xl border p-3"
                >
                  <h3 className="mb-3 text-sm font-semibold capitalize">
                    {stage.replaceAll("_", " ")}
                  </h3>
                  <div className="space-y-2">
                    {items.map((application) => (
                      <div
                        key={application.id}
                        className="bg-background rounded-lg border p-3"
                      >
                        <p className="font-medium">
                          {application.candidate.first_name}{" "}
                          {application.candidate.last_name}
                        </p>
                        <p className="text-muted-foreground text-sm">
                          {application.candidate.email || "No email"}
                        </p>
                        <Button
                          asChild
                          className="mt-3"
                          size="sm"
                          variant="outline"
                        >
                          <Link
                            href={`/candidates/${application.candidate.id}?application_id=${application.id}&schedule_meeting=1`}
                          >
                            Schedule meeting
                          </Link>
                        </Button>
                        <Form
                          action={`/applications/${application.id}`}
                          method="patch"
                          className="mt-3 flex gap-2"
                        >
                          {() => (
                            <>
                              <select
                                name="stage"
                                defaultValue={stage}
                                className="border-input h-8 min-w-0 flex-1 rounded-md border bg-transparent px-2 text-xs"
                              >
                                {stages.map((option) => (
                                  <option key={option} value={option}>
                                    {option.replaceAll("_", " ")}
                                  </option>
                                ))}
                              </select>
                              <Button
                                type="submit"
                                size="sm"
                                variant="secondary"
                              >
                                Move
                              </Button>
                            </>
                          )}
                        </Form>
                      </div>
                    ))}
                  </div>
                </section>
              )
            })}
          </div>
        </section>
      </main>
    </AppLayout>
  )
}

function RoleBrief({ job }: { job: Job }) {
  return (
    <section className="rounded-xl border p-5">
      <div className="mb-4 flex items-center gap-2">
        <FileText className="size-4" />
        <h2 className="font-semibold">Role brief</h2>
      </div>
      <Form action={`/jobs/${job.id}`} method="patch">
        {({ processing, errors }) => (
          <FieldGroup>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field>
                <FieldLabel htmlFor="seniority">Seniority</FieldLabel>
                <Input
                  id="seniority"
                  name="seniority"
                  defaultValue={job.seniority || ""}
                  placeholder="Senior"
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="technology_stack">
                  Technology stack
                </FieldLabel>
                <Input
                  id="technology_stack"
                  name="technology_stack"
                  defaultValue={job.technology_stack || ""}
                  placeholder="React, TypeScript, PostgreSQL"
                />
              </Field>
            </div>
            <Field>
              <FieldLabel htmlFor="description">
                Internal role description
              </FieldLabel>
              <textarea
                id="description"
                name="description"
                defaultValue={job.description || ""}
                className="border-input min-h-32 w-full rounded-md border bg-transparent p-3 text-sm"
                placeholder="The client need, mission, outcomes, and constraints. This is the internal source of truth."
              />
              <FieldError
                errors={errors.description?.map((message) => ({ message }))}
              />
            </Field>
            <Button type="submit" disabled={processing}>
              Save role brief
            </Button>
          </FieldGroup>
        )}
      </Form>
    </section>
  )
}

function SourcingBriefEditor({
  job,
  sourcingBrief,
  statuses,
}: {
  job: Job
  sourcingBrief: SourcingBrief
  statuses: string[]
}) {
  const action = sourcingBrief
    ? `/jobs/${job.id}/sourcing_brief`
    : `/jobs/${job.id}/sourcing_brief`
  const method = sourcingBrief ? "patch" : "post"
  return (
    <section className="rounded-xl border p-5">
      <div className="mb-2 flex items-center gap-2">
        <Sparkles className="size-4" />
        <h2 className="font-semibold">Sourcing brief</h2>
      </div>
      <p className="text-muted-foreground mb-4 text-sm">
        A recruiter-approved target profile. An AI draft can populate these
        fields later, but it never decides whom to reject.
      </p>
      <Form action={action} method={method}>
        {({ processing, errors }) => (
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="summary">Ideal candidate summary</FieldLabel>
              <textarea
                id="summary"
                name="summary"
                defaultValue={sourcingBrief?.summary || ""}
                className="border-input min-h-20 w-full rounded-md border bg-transparent p-3 text-sm"
                placeholder="The profile and background most likely to succeed in this role."
              />
            </Field>
            <div className="grid gap-4 sm:grid-cols-2">
              <ListField
                id="must_haves"
                label="Must-haves"
                value={sourcingBrief?.must_haves}
                placeholder="React, TypeScript, B2 English"
              />
              <ListField
                id="nice_to_haves"
                label="Nice-to-haves"
                value={sourcingBrief?.nice_to_haves}
                placeholder="Next.js, fintech"
              />
              <ListField
                id="location_preferences"
                label="Location / time zones"
                value={sourcingBrief?.location_preferences}
                placeholder="Europe, UTC−3 to UTC+3"
              />
              <Field>
                <FieldLabel htmlFor="language_requirement">
                  Language requirement
                </FieldLabel>
                <Input
                  id="language_requirement"
                  name="language_requirement"
                  defaultValue={sourcingBrief?.language_requirement || ""}
                  placeholder="English B2+"
                />
              </Field>
            </div>
            <ListField
              id="exclusions"
              label="Exclusions"
              value={sourcingBrief?.exclusions}
              placeholder="Unavailable for 60+ days"
            />
            <ListField
              id="search_queries"
              label="Search queries"
              value={sourcingBrief?.search_queries}
              placeholder="React AND TypeScript AND accessibility"
            />
            <Field>
              <FieldLabel htmlFor="interview_focus">Interview focus</FieldLabel>
              <textarea
                id="interview_focus"
                name="interview_focus"
                defaultValue={sourcingBrief?.interview_focus || ""}
                className="border-input min-h-20 w-full rounded-md border bg-transparent p-3 text-sm"
                placeholder="Topics to validate during screening and interviews."
              />
            </Field>
            <Field>
              <FieldLabel htmlFor="brief_status">Review state</FieldLabel>
              <select
                id="brief_status"
                name="status"
                defaultValue={sourcingBrief?.status || "draft"}
                className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
              >
                {statuses.map((status) => (
                  <option key={status} value={status}>
                    {status === "approved"
                      ? "Approved for sourcing"
                      : "Draft — needs recruiter review"}
                  </option>
                ))}
              </select>
            </Field>
            <FieldError errors={errors.base?.map((message) => ({ message }))} />
            <Button type="submit" disabled={processing}>
              {sourcingBrief
                ? "Update sourcing brief"
                : "Create sourcing brief"}
            </Button>
          </FieldGroup>
        )}
      </Form>
    </section>
  )
}

function ListField({
  id,
  label,
  value,
  placeholder,
}: {
  id: string
  label: string
  value?: string[]
  placeholder: string
}) {
  return (
    <Field>
      <FieldLabel htmlFor={id}>{label}</FieldLabel>
      <Input
        id={id}
        name={`${id}[]`}
        defaultValue={value?.join(", ") || ""}
        placeholder={placeholder}
      />
      <p className="text-muted-foreground text-xs">Comma-separated</p>
    </Field>
  )
}

function JobPostings({
  job,
  postings,
  channels,
  statuses,
}: {
  job: Job
  postings: Posting[]
  channels: string[]
  statuses: string[]
}) {
  return (
    <section className="rounded-xl border p-5">
      <h2 className="font-semibold">Public job postings</h2>
      <p className="text-muted-foreground mt-1 text-sm">
        A posting is an external advertisement; the role brief remains the
        internal source of truth.
      </p>
      <div className="mt-4 space-y-2">
        {postings.length === 0 ? (
          <p className="text-muted-foreground rounded-lg border border-dashed p-3 text-sm">
            No public posting linked yet.
          </p>
        ) : (
          postings.map((posting) => (
            <div
              key={posting.id}
              className="flex items-center justify-between gap-3 rounded-lg border p-3"
            >
              <div>
                <p className="font-medium">{posting.title || job.title}</p>
                <p className="text-muted-foreground text-sm capitalize">
                  {posting.channel.replaceAll("_", " ")} · {posting.status}
                </p>
              </div>
              <a
                href={posting.public_url}
                target="_blank"
                rel="noreferrer"
                className="text-muted-foreground hover:text-foreground"
              >
                <ExternalLink className="size-4" />
                <span className="sr-only">Open public posting</span>
              </a>
            </div>
          ))
        )}
      </div>
      <details className="mt-4">
        <summary className="cursor-pointer text-sm font-medium">
          Link a public posting
        </summary>
        <Form action="/job_postings" method="post" className="mt-4">
          {({ processing, errors }) => (
            <FieldGroup>
              <input type="hidden" name="job_id" value={job.id} />
              <div className="grid gap-4 sm:grid-cols-2">
                <Field>
                  <FieldLabel htmlFor="posting_channel">Channel</FieldLabel>
                  <select
                    id="posting_channel"
                    name="channel"
                    defaultValue="careers_site"
                    className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
                  >
                    {channels.map((channel) => (
                      <option key={channel} value={channel}>
                        {channel.replaceAll("_", " ")}
                      </option>
                    ))}
                  </select>
                </Field>
                <Field>
                  <FieldLabel htmlFor="posting_status">Status</FieldLabel>
                  <select
                    id="posting_status"
                    name="status"
                    defaultValue="published"
                    className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
                  >
                    {statuses.map((status) => (
                      <option key={status} value={status}>
                        {status}
                      </option>
                    ))}
                  </select>
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor="public_url">Public URL</FieldLabel>
                <Input
                  id="public_url"
                  name="public_url"
                  type="url"
                  required
                  placeholder="https://company.example/careers/role"
                />
                <FieldError
                  errors={errors.public_url?.map((message) => ({ message }))}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="posting_title">Posting title</FieldLabel>
                <Input
                  id="posting_title"
                  name="title"
                  placeholder={job.title}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="content_snapshot">
                  Posting snapshot
                </FieldLabel>
                <textarea
                  id="content_snapshot"
                  name="content_snapshot"
                  className="border-input min-h-20 w-full rounded-md border bg-transparent p-3 text-sm"
                  placeholder="Paste the published text or a recruiter-maintained snapshot. It preserves context if the external page changes."
                />
              </Field>
              <Button type="submit" disabled={processing}>
                Save public posting
              </Button>
            </FieldGroup>
          )}
        </Form>
      </details>
    </section>
  )
}

function SourcingGuidance({ sourcingBrief }: { sourcingBrief: SourcingBrief }) {
  return (
    <section className="rounded-xl border p-5">
      <h2 className="font-semibold">How to use this brief</h2>
      {sourcingBrief?.status === "approved" ? (
        <p className="text-muted-foreground mt-2 text-sm">
          This target profile is approved for sourcing. Use its must-haves and
          search queries when evaluating candidates; record exceptions
          explicitly.
        </p>
      ) : (
        <p className="text-muted-foreground mt-2 text-sm">
          Draft the target profile before broad sourcing. Keep it
          recruiter-owned and revise it when the client changes the need.
        </p>
      )}
    </section>
  )
}
