import { Form, Head, Link } from "@inertiajs/react"
import Heading from "@/components/heading"
import { Button } from "@/components/ui/button"
import { Field, FieldError, FieldLabel } from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import AppLayout from "@/layouts/app-layout"

type Client = { id: string; name: string }
export default function Projects({
  clients,
  projects,
}: {
  clients: Client[]
  projects: { id: string; name: string; client: string }[]
}) {
  return (
    <AppLayout breadcrumbs={[{ title: "Projects", href: "/projects" }]}>
      <Head title="Projects" />
      <div className="max-w-3xl p-6">
        <Heading
          title="Projects"
          description="Client engagements that can contain many roles and technology stacks."
        />
        {clients.length === 0 ? (
          <p className="text-muted-foreground">
            Add a client before creating a project.
          </p>
        ) : (
          <Form
            action="/projects"
            method="post"
            className="mb-8 grid gap-3 sm:grid-cols-3"
          >
            {({ errors }) => (
              <>
                <Field>
                  <FieldLabel htmlFor="name">Project name</FieldLabel>
                  <Input id="name" name="name" required />
                </Field>
                <Field>
                  <FieldLabel htmlFor="client_company_id">Client</FieldLabel>
                  <select
                    id="client_company_id"
                    name="client_company_id"
                    className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
                    required
                  >
                    {clients.map((client) => (
                      <option key={client.id} value={client.id}>
                        {client.name}
                      </option>
                    ))}
                  </select>
                  <FieldError
                    errors={errors.client_company_id?.map((message) => ({
                      message,
                    }))}
                  />
                </Field>
                <Button className="self-end" type="submit">
                  Add project
                </Button>
              </>
            )}
          </Form>
        )}
        <div className="space-y-2">
          {projects.map((project) => (
            <div key={project.id} className="rounded-lg border p-3">
              <span className="font-medium">{project.name}</span>
              <span className="text-muted-foreground"> · {project.client}</span>
            </div>
          ))}
        </div>
        <Button asChild variant="link" className="mt-4 px-0">
          <Link href="/jobs">Continue to jobs</Link>
        </Button>
      </div>
    </AppLayout>
  )
}
