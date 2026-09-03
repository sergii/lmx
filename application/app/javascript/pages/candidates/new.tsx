import { Form, Head } from "@inertiajs/react"

import Heading from "@/components/heading"
import { Button } from "@/components/ui/button"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { Spinner } from "@/components/ui/spinner"
import AppLayout from "@/layouts/app-layout"

export default function NewCandidate({
  consentStatuses,
  languageProficiencyLevels,
  jobs,
  selectedJobId,
}: {
  consentStatuses: string[]
  languageProficiencyLevels: { value: string; full_label: string }[]
  jobs: { id: string; title: string; project: string; client: string }[]
  selectedJobId?: string
}) {
  return (
    <AppLayout
      breadcrumbs={[
        { title: "Candidates", href: "/candidates" },
        { title: "Add candidate", href: "/candidates/new" },
      ]}
    >
      <Head title="Add candidate" />
      <div className="max-w-2xl p-6">
        <Heading
          title="Add candidate"
          description="This profile is visible only within the current workspace."
        />
        <Form action="/candidates" method="post" className="space-y-6">
          {({ processing, errors }) => (
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="job_id">Job</FieldLabel>
                <select
                  id="job_id"
                  name="job_id"
                  defaultValue={selectedJobId}
                  className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
                  required
                >
                  <option value="" disabled>
                    Select a job
                  </option>
                  {jobs.map((job) => (
                    <option key={job.id} value={job.id}>
                      {job.title} — {job.project} / {job.client}
                    </option>
                  ))}
                </select>
                <FieldError
                  errors={errors.job?.map((message) => ({ message }))}
                />
              </Field>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field>
                  <FieldLabel htmlFor="first_name">First name</FieldLabel>
                  <Input id="first_name" name="first_name" required autoFocus />
                  <FieldError
                    errors={errors.first_name?.map((message) => ({ message }))}
                  />
                </Field>
                <Field>
                  <FieldLabel htmlFor="last_name">Last name</FieldLabel>
                  <Input id="last_name" name="last_name" required />
                  <FieldError
                    errors={errors.last_name?.map((message) => ({ message }))}
                  />
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor="email">Email</FieldLabel>
                <Input id="email" name="email" type="email" />
                <FieldError
                  errors={errors.email?.map((message) => ({ message }))}
                />
              </Field>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field>
                  <FieldLabel htmlFor="location">Location</FieldLabel>
                  <Input
                    id="location"
                    name="location"
                    placeholder="Buenos Aires, Argentina"
                  />
                </Field>
                <Field>
                  <FieldLabel htmlFor="time_zone">Time zone</FieldLabel>
                  <Input
                    id="time_zone"
                    name="time_zone"
                    placeholder="America/Argentina/Buenos_Aires"
                  />
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor="source">Source</FieldLabel>
                <Input
                  id="source"
                  name="source"
                  placeholder="Referral, LinkedIn, inbound…"
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="english_proficiency_level">
                  English proficiency
                </FieldLabel>
                <select
                  id="english_proficiency_level"
                  name="english_proficiency_level"
                  defaultValue=""
                  className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
                >
                  <option value="">Not assessed</option>
                  {languageProficiencyLevels.map((level) => (
                    <option key={level.value} value={level.value}>
                      {level.full_label}
                    </option>
                  ))}
                </select>
              </Field>
              <Field>
                <FieldLabel htmlFor="consent_status">Consent status</FieldLabel>
                <select
                  id="consent_status"
                  name="consent_status"
                  defaultValue="unknown"
                  className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
                >
                  {consentStatuses.map((status) => (
                    <option key={status} value={status}>
                      {status}
                    </option>
                  ))}
                </select>
                <FieldError
                  errors={errors.consent_status?.map((message) => ({
                    message,
                  }))}
                />
              </Field>
              <Button type="submit" disabled={processing}>
                {processing && <Spinner />}Create candidate
              </Button>
            </FieldGroup>
          )}
        </Form>
      </div>
    </AppLayout>
  )
}
