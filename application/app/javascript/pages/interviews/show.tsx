import { Form, Head } from "@inertiajs/react"
import { FileCheck2, ShieldCheck } from "lucide-react"

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

type Interview = {
  id: string
  status: string
  template_name: string | null
  language: string | null
  interviewer_notes: string | null
  transcript: string | null
  recording_url: string | null
  completed_at: string | null
  candidate: { id: string; name: string }
  application: { id: string; role: string } | null
  meeting: { id: string; status: string; scheduled_at: string } | null
}

type Assessment = {
  id: string
  status: string
  assessor: string
  overall_level: string | null
  rating: number | null
  recommendation: string | null
  strong_sides: string | null
  improvement_areas: string | null
  overall_comments: string | null
}

export default function InterviewShow({
  interview,
  assessments,
  assessmentStatuses,
}: {
  interview: Interview
  assessments: Assessment[]
  assessmentStatuses: string[]
}) {
  const canAssess =
    interview.status === "completed" &&
    interview.meeting?.status !== "cancelled"

  return (
    <AppLayout
      breadcrumbs={[
        { title: "Candidates", href: "/candidates" },
        {
          title: interview.candidate.name,
          href: `/candidates/${interview.candidate.id}`,
        },
        { title: "Interview", href: `/interviews/${interview.id}` },
      ]}
    >
      <Head title={`Interview · ${interview.candidate.name}`} />
      <main className="max-w-4xl p-6">
        <Heading
          title={`Interview · ${interview.candidate.name}`}
          description="Internal interview activity, evidence source material, and assessor-owned feedback."
        />
        <section className="mt-6 rounded-xl border p-5">
          <dl className="grid gap-4 sm:grid-cols-3">
            <Detail label="Status" value={interview.status} />
            <Detail
              label="Role"
              value={
                interview.application?.role ?? "General candidate evaluation"
              }
            />
            <Detail
              label="Template"
              value={interview.template_name ?? "No template"}
            />
            <Detail label="Language" value={interview.language ?? "—"} />
            <Detail
              label="Meeting"
              value={
                interview.meeting
                  ? new Date(interview.meeting.scheduled_at).toLocaleString()
                  : "Asynchronous / no meeting"
              }
            />
            <Detail
              label="Recording"
              value={interview.recording_url ? "Attached" : "Not attached"}
            />
          </dl>
          <div className="mt-5 grid gap-5 md:grid-cols-2">
            <Narrative
              title="Interviewer notes"
              value={interview.interviewer_notes}
            />
            <Narrative title="Transcript" value={interview.transcript} />
          </div>
        </section>

        <section className="mt-6 rounded-xl border p-5">
          <div className="flex items-center gap-2">
            <ShieldCheck className="size-5" />
            <div>
              <h2 className="font-semibold">Assessments</h2>
              <p className="text-muted-foreground text-sm">
                These records are internal-only and never exposed through the
                client portal.
              </p>
            </div>
          </div>
          {assessments.length > 0 && (
            <div className="mt-5 space-y-3">
              {assessments.map((assessment) => (
                <AssessmentCard key={assessment.id} assessment={assessment} />
              ))}
            </div>
          )}
          {canAssess ? (
            <AssessmentForm
              interviewId={interview.id}
              statuses={assessmentStatuses}
            />
          ) : (
            <p className="text-muted-foreground mt-5 text-sm">
              An assessment can be created only after a completed interview that
              is not tied to a cancelled meeting.
            </p>
          )}
        </section>
      </main>
    </AppLayout>
  )
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-muted-foreground text-xs">{label}</dt>
      <dd className="mt-1 capitalize">{value.replaceAll("_", " ")}</dd>
    </div>
  )
}

function Narrative({ title, value }: { title: string; value: string | null }) {
  return (
    <div>
      <h3 className="font-medium">{title}</h3>
      <p className="text-muted-foreground mt-1 text-sm whitespace-pre-wrap">
        {value || "No material recorded."}
      </p>
    </div>
  )
}

function AssessmentCard({ assessment }: { assessment: Assessment }) {
  return (
    <article className="rounded-lg border p-4">
      <div className="flex flex-wrap justify-between gap-2">
        <div>
          <p className="font-medium">{assessment.assessor}</p>
          <p className="text-muted-foreground text-sm capitalize">
            {assessment.status.replaceAll("_", " ")}
          </p>
        </div>
        <span className="bg-muted rounded-full px-2.5 py-1 text-sm">
          {assessment.rating ? `${assessment.rating}/5` : "No rating"}
        </span>
      </div>
      <p className="mt-3 text-sm">
        <span className="font-medium">Recommendation:</span>{" "}
        {assessment.recommendation || "Not recorded"}
      </p>
      {assessment.overall_comments && (
        <p className="text-muted-foreground mt-2 text-sm">
          {assessment.overall_comments}
        </p>
      )}
    </article>
  )
}

function AssessmentForm({
  interviewId,
  statuses,
}: {
  interviewId: string
  statuses: string[]
}) {
  return (
    <Form
      action={`/interviews/${interviewId}/assessments`}
      method="post"
      className="mt-6 border-t pt-5"
    >
      {({ processing, errors }) => (
        <FieldGroup>
          <div>
            <h3 className="flex items-center gap-2 font-medium">
              <FileCheck2 className="size-4" /> Add assessment
            </h3>
            <p className="text-muted-foreground mt-1 text-sm">
              Your draft is attributed to you. Final values remain human-owned.
            </p>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field>
              <FieldLabel htmlFor="status">Status</FieldLabel>
              <select
                id="status"
                name="status"
                defaultValue="draft"
                className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
              >
                {statuses.map((status) => (
                  <option key={status} value={status}>
                    {status.replaceAll("_", " ")}
                  </option>
                ))}
              </select>
            </Field>
            <Field>
              <FieldLabel htmlFor="rating">Rating</FieldLabel>
              <Input id="rating" name="rating" type="number" min="1" max="5" />
            </Field>
          </div>
          <Field>
            <FieldLabel htmlFor="recommendation">Recommendation</FieldLabel>
            <Input
              id="recommendation"
              name="recommendation"
              placeholder="Advance, hold, or decline"
            />
          </Field>
          <Field>
            <FieldLabel htmlFor="overall_comments">Overall comments</FieldLabel>
            <textarea
              id="overall_comments"
              name="overall_comments"
              className="border-input min-h-24 w-full rounded-md border bg-transparent p-3 text-sm"
            />
          </Field>
          <FieldError
            errors={errors.interview?.map((message) => ({ message }))}
          />
          <Button type="submit" disabled={processing}>
            Save assessment
          </Button>
        </FieldGroup>
      )}
    </Form>
  )
}
