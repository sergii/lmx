import { Form, Head } from "@inertiajs/react"
import { Mail, UserPlus, UsersRound } from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import AppLayout from "@/layouts/app-layout"

type Member = { id: string; name: string; email: string; role: string }
type Invitation = {
  id: string
  email: string
  role: string
  created_at: string
}

export default function TeamSettings({
  members,
  invitations,
  roles,
}: {
  members: Member[]
  invitations: Invitation[]
  roles: Record<string, string>
}) {
  return (
    <AppLayout breadcrumbs={[{ title: "Team", href: "/settings/team" }]}>
      <Head title="Invite team members" />
      <div className="max-w-3xl p-6">
        <div className="flex items-start gap-3">
          <span className="bg-primary/10 text-primary flex size-10 items-center justify-center rounded-xl">
            <UsersRound className="size-5" />
          </span>
          <div>
            <h1 className="text-xl font-semibold">Invite team members</h1>
            <p className="text-muted-foreground mt-1 text-sm">
              Give your recruiting team access to this workspace.
            </p>
          </div>
        </div>

        <Form action="/settings/team" method="post" className="mt-8">
          {({ processing, errors }) => (
            <FieldGroup className="rounded-xl border p-5">
              <div>
                <h2 className="font-medium">New invitation</h2>
                <p className="text-muted-foreground mt-1 text-sm">
                  Choose the access level before sending an invitation.
                </p>
              </div>
              <div className="grid gap-4 sm:grid-cols-[minmax(0,1fr)_180px_auto] sm:items-end">
                <Field>
                  <FieldLabel htmlFor="email">Email address</FieldLabel>
                  <Input
                    id="email"
                    name="email"
                    type="email"
                    required
                    placeholder="teammate@company.com"
                  />
                  <FieldError
                    errors={errors.email?.map((message) => ({ message }))}
                  />
                </Field>
                <Field>
                  <FieldLabel htmlFor="role">Role</FieldLabel>
                  <select
                    id="role"
                    name="role"
                    defaultValue="recruiter"
                    className="border-input focus-visible:ring-ring/50 h-9 w-full rounded-md border bg-transparent px-3 text-sm shadow-xs outline-none focus-visible:ring-3"
                  >
                    {Object.entries(roles).map(([value, label]) => (
                      <option key={value} value={value}>
                        {label}
                      </option>
                    ))}
                  </select>
                  <FieldError
                    errors={errors.role?.map((message) => ({ message }))}
                  />
                </Field>
                <Button type="submit" disabled={processing}>
                  <UserPlus /> Invite
                </Button>
              </div>
              <p className="text-muted-foreground text-xs">
                Invitations are recorded now; email delivery will be connected
                before inviting external teammates.
              </p>
            </FieldGroup>
          )}
        </Form>

        <section className="mt-8">
          <h2 className="font-medium">Team members</h2>
          <div className="mt-3 overflow-hidden rounded-xl border">
            {members.map((member) => (
              <div
                key={member.id}
                className="flex items-center justify-between gap-4 border-b px-4 py-3 last:border-b-0"
              >
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium">{member.name}</p>
                  <p className="text-muted-foreground truncate text-sm">
                    {member.email}
                  </p>
                </div>
                <Badge variant="secondary">
                  {member.role.replaceAll("_", " ")}
                </Badge>
              </div>
            ))}
          </div>
        </section>

        <section className="mt-8">
          <h2 className="font-medium">Pending invitations</h2>
          {invitations.length === 0 ? (
            <p className="text-muted-foreground mt-3 rounded-xl border border-dashed p-5 text-sm">
              No invitations are waiting to be accepted.
            </p>
          ) : (
            <div className="mt-3 overflow-hidden rounded-xl border">
              {invitations.map((invitation) => (
                <div
                  key={invitation.id}
                  className="flex items-center justify-between gap-4 border-b px-4 py-3 last:border-b-0"
                >
                  <div className="flex min-w-0 items-center gap-3">
                    <span className="bg-muted flex size-8 shrink-0 items-center justify-center rounded-full">
                      <Mail className="size-4" />
                    </span>
                    <p className="text-sm font-medium">{invitation.email}</p>
                  </div>
                  <Badge variant="outline">
                    {invitation.role.replaceAll("_", " ")}
                  </Badge>
                </div>
              ))}
            </div>
          )}
        </section>
      </div>
    </AppLayout>
  )
}
