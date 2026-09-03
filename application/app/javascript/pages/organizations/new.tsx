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
import AuthLayout from "@/layouts/auth-layout"

export default function NewOrganization() {
  return (
    <AuthLayout
      title="Create your workspace"
      description="Your workspace is the secure boundary for candidates and hiring work."
    >
      <Head title="Create workspace" />
      <Form
        action="/organizations"
        method="post"
        className="flex flex-col gap-6"
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
                placeholder="Acme Recruiting"
              />
              <FieldError
                errors={errors.name?.map((message) => ({ message }))}
              />
            </Field>
            <Button type="submit" disabled={processing}>
              {processing && <Spinner />}
              Create workspace
            </Button>
          </FieldGroup>
        )}
      </Form>
    </AuthLayout>
  )
}
