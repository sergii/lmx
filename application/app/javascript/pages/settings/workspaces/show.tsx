import { Form, Head } from "@inertiajs/react"

import { Button } from "@/components/ui/button"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import AppLayout from "@/layouts/app-layout"

type Workspace = { name: string; logo_url?: string | null }

export default function WorkspaceSettings({
  workspace,
}: {
  workspace: Workspace
}) {
  return (
    <AppLayout
      breadcrumbs={[
        { title: "Workspace settings", href: "/settings/workspace" },
      ]}
    >
      <Head title="Workspace settings" />
      <div className="max-w-2xl p-6">
        <h1 className="text-xl font-semibold">Workspace settings</h1>
        <p className="text-muted-foreground mt-1 text-sm">
          Manage the name and logo your team sees throughout Hire.do.
        </p>
        <Form
          action="/settings/workspace"
          method="patch"
          encType="multipart/form-data"
          className="mt-8"
        >
          {({ processing, errors }) => (
            <FieldGroup className="rounded-xl border p-5">
              <Field>
                <FieldLabel>Current logo</FieldLabel>
                <div className="bg-muted flex size-24 items-center justify-center overflow-hidden rounded-full border text-lg font-semibold shadow-sm">
                  {workspace.logo_url ? (
                    <img
                      src={workspace.logo_url}
                      alt={`${workspace.name} logo`}
                      className="size-full bg-white object-contain p-3"
                    />
                  ) : (
                    workspace.name.slice(0, 1).toUpperCase()
                  )}
                </div>
              </Field>
              <Field>
                <FieldLabel htmlFor="name">Workspace name</FieldLabel>
                <Input
                  id="name"
                  name="name"
                  required
                  defaultValue={workspace.name}
                />
                <FieldError
                  errors={errors.name?.map((message) => ({ message }))}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="logo">Replace logo</FieldLabel>
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
              <Button type="submit" disabled={processing}>
                Save workspace
              </Button>
            </FieldGroup>
          )}
        </Form>
      </div>
    </AppLayout>
  )
}
