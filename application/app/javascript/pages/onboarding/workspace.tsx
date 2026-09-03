import { Form, Head } from "@inertiajs/react"

import { Button } from "@/components/ui/button"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { Spinner } from "@/components/ui/spinner"
import OnboardingLayout from "@/layouts/onboarding-layout"

export default function Workspace({
  suggested_name,
}: {
  suggested_name: string | null
}) {
  return (
    <OnboardingLayout
      step={2}
      title="Create your workspace"
      description="A workspace is the secure home for your recruiting team, clients, roles, and candidates."
    >
      <Head title="Create your workspace" />
      <Form
        action="/onboarding/workspace"
        method="post"
        encType="multipart/form-data"
        className="space-y-6"
      >
        {({ processing, errors }) => (
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="name">Workspace name</FieldLabel>
              <Input
                id="name"
                name="name"
                required
                autoFocus
                defaultValue={suggested_name ?? undefined}
                placeholder="TurnKey Staffing"
              />
              <FieldError
                errors={errors.name?.map((message) => ({ message }))}
              />
            </Field>
            <Field>
              <FieldLabel htmlFor="logo">
                Workspace logo{" "}
                <span className="text-muted-foreground font-normal">
                  (optional)
                </span>
              </FieldLabel>
              <Input
                id="logo"
                name="logo"
                type="file"
                accept="image/png,image/jpeg,image/webp,image/svg+xml"
              />
              <p className="text-muted-foreground text-xs">
                PNG, JPEG, WebP, or SVG. Maximum 2 MB.
              </p>
              <FieldError
                errors={errors.logo?.map((message) => ({ message }))}
              />
            </Field>
            <Button type="submit" className="w-full" disabled={processing}>
              {processing && <Spinner />}
              Create workspace
            </Button>
          </FieldGroup>
        )}
      </Form>
    </OnboardingLayout>
  )
}
