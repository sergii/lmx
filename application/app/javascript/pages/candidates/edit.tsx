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
import AppLayout from "@/layouts/app-layout"

type Level = { value: string; full_label: string }
type Proficiency = {
  value: string
  code: string
  label: string
  full_label: string
} | null

export default function EditCandidate({
  candidate,
  consentStatuses,
  languageProficiencyLevels,
}: {
  candidate: Record<string, string | string[] | Proficiency | null>
  consentStatuses: string[]
  languageProficiencyLevels: Level[]
}) {
  const englishProficiency = candidate.english_proficiency as Proficiency

  return (
    <AppLayout
      breadcrumbs={[
        { title: "Candidates", href: "/candidates" },
        { title: "Edit profile", href: `/candidates/${candidate.id}` },
      ]}
    >
      <Head title="Edit candidate" />
      <div className="max-w-3xl p-6">
        <Heading title="Edit candidate profile" />
        <Form
          action={`/candidates/${candidate.id}`}
          method="patch"
          className="space-y-5"
        >
          {({ errors }) => (
            <FieldGroup>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field>
                  <FieldLabel>First name</FieldLabel>
                  <Input
                    name="first_name"
                    defaultValue={candidate.first_name as string}
                    required
                  />
                </Field>
                <Field>
                  <FieldLabel>Last name</FieldLabel>
                  <Input
                    name="last_name"
                    defaultValue={candidate.last_name as string}
                    required
                  />
                </Field>
              </div>
              <Field>
                <FieldLabel>Email</FieldLabel>
                <Input
                  name="email"
                  type="email"
                  defaultValue={candidate.email as string}
                />
              </Field>
              <Field>
                <FieldLabel>Skills</FieldLabel>
                <Input
                  name="skills"
                  defaultValue={(candidate.skills as string[]).join(", ")}
                  placeholder="React, TypeScript, PostgreSQL"
                />
              </Field>
              <Field>
                <FieldLabel>Tags</FieldLabel>
                <Input
                  name="tags"
                  defaultValue={(candidate.tags as string[]).join(", ")}
                  placeholder="LATAM, referral"
                />
              </Field>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field>
                  <FieldLabel>LinkedIn URL</FieldLabel>
                  <Input
                    name="linkedin_url"
                    defaultValue={candidate.linkedin_url as string}
                  />
                </Field>
                <Field>
                  <FieldLabel>GitHub URL</FieldLabel>
                  <Input
                    name="github_url"
                    defaultValue={candidate.github_url as string}
                  />
                </Field>
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field>
                  <FieldLabel>English proficiency</FieldLabel>
                  <select
                    name="english_proficiency_level"
                    defaultValue={englishProficiency?.value || ""}
                    className="border-input h-9 rounded-md border bg-transparent px-3"
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
                  <FieldLabel>Consent</FieldLabel>
                  <select
                    name="consent_status"
                    defaultValue={candidate.consent_status as string}
                    className="border-input h-9 rounded-md border bg-transparent px-3"
                  >
                    {consentStatuses.map((status) => (
                      <option key={status} value={status}>
                        {status}
                      </option>
                    ))}
                  </select>
                </Field>
              </div>
              <Field>
                <FieldLabel>Notes</FieldLabel>
                <textarea
                  name="notes"
                  defaultValue={candidate.notes as string}
                  className="border-input min-h-28 w-full rounded-md border bg-transparent p-3"
                />
              </Field>
              <FieldError
                errors={errors.base?.map((message) => ({ message }))}
              />
              <Button type="submit">Save profile</Button>
            </FieldGroup>
          )}
        </Form>
      </div>
    </AppLayout>
  )
}
