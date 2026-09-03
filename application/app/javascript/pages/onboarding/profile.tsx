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

export default function Profile({
  user,
}: {
  user: { name: string; email: string }
}) {
  return (
    <OnboardingLayout
      step={1}
      title="Let’s get to know you"
      description="This helps your teammates recognize who is working in the workspace. You can change it later."
    >
      <Head title="Set up your profile" />
      <Form action="/onboarding/profile" method="patch" className="space-y-6">
        {({ processing, errors }) => (
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="name">Your name</FieldLabel>
              <Input
                id="name"
                name="name"
                required
                autoFocus
                defaultValue={user.name}
                placeholder="Ada Lovelace"
              />
              <FieldError
                errors={errors.name?.map((message) => ({ message }))}
              />
            </Field>
            <Field>
              <FieldLabel htmlFor="email">Email</FieldLabel>
              <Input
                id="email"
                value={user.email}
                readOnly
                aria-readonly="true"
                className="bg-muted"
              />
            </Field>
            <Button type="submit" className="w-full" disabled={processing}>
              {processing && <Spinner />}
              Continue
            </Button>
          </FieldGroup>
        )}
      </Form>
    </OnboardingLayout>
  )
}
