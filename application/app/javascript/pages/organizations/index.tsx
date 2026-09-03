import { Form, Head, Link } from "@inertiajs/react"

import { Button } from "@/components/ui/button"
import AuthLayout from "@/layouts/auth-layout"

type Organization = {
  id: string
  name: string
  role: string
  logo_url?: string | null
}

export default function Organizations({
  organizations,
}: {
  organizations: Organization[]
}) {
  return (
    <AuthLayout
      title="Choose a workspace"
      description="Select the workspace you want to open."
    >
      <Head title="Workspaces" />
      <div className="space-y-3">
        {organizations.map((organization) => (
          <Form
            key={organization.id}
            action="/organization_selection"
            method="post"
          >
            <input
              type="hidden"
              name="organization_id"
              value={organization.id}
            />
            <Button
              type="submit"
              variant="outline"
              className="h-auto w-full justify-between p-4"
            >
              <span className="flex items-center gap-3">
                {organization.logo_url ? (
                  <img
                    src={organization.logo_url}
                    alt=""
                    className="size-7 rounded-full bg-white object-contain p-1"
                  />
                ) : (
                  <span className="bg-primary text-primary-foreground flex size-7 items-center justify-center rounded-full text-xs font-semibold">
                    {organization.name.slice(0, 1).toUpperCase()}
                  </span>
                )}
                {organization.name}
              </span>
              <span className="text-muted-foreground text-xs">
                {organization.role.replaceAll("_", " ")}
              </span>
            </Button>
          </Form>
        ))}
        <Button asChild variant="secondary" className="w-full">
          <Link href="/organizations/new">Create another workspace</Link>
        </Button>
      </div>
    </AuthLayout>
  )
}
