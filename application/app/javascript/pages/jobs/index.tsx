import { Form, Head, Link } from "@inertiajs/react"
import Heading from "@/components/heading"
import { Button } from "@/components/ui/button"
import { Field, FieldError, FieldLabel } from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import AppLayout from "@/layouts/app-layout"

type Project = { id: string; name: string; client: string }
export default function Jobs({
  projects,
  jobs,
}: {
  projects: Project[]
  jobs: {
    id: string
    title: string
    seniority: string | null
    technology_stack: string | null
    status: string
    project: string
    client: string
  }[]
}) {
  return (
    <AppLayout breadcrumbs={[{ title: "Jobs", href: "/jobs" }]}>
      <Head title="Jobs" />
      <div className="p-6">
        <Heading
          title="Jobs"
          description="Create a draft role as soon as a sourcing need exists."
        />
        {projects.length === 0 ? (
          <p className="text-muted-foreground">
            Create a client and project before adding a job.
          </p>
        ) : (
          <Form
            action="/jobs"
            method="post"
            className="mb-8 grid gap-3 md:grid-cols-5"
          >
            {({ errors }) => (
              <>
                <Field>
                  <FieldLabel htmlFor="project_id">Project</FieldLabel>
                  <select
                    id="project_id"
                    name="project_id"
                    className="border-input h-9 w-full rounded-md border bg-transparent px-3 text-sm"
                    required
                  >
                    {projects.map((project) => (
                      <option key={project.id} value={project.id}>
                        {project.client} — {project.name}
                      </option>
                    ))}
                  </select>
                </Field>
                <Field>
                  <FieldLabel htmlFor="title">Role</FieldLabel>
                  <Input
                    id="title"
                    name="title"
                    required
                    placeholder="Senior React Engineer"
                  />
                  <FieldError
                    errors={errors.title?.map((message) => ({ message }))}
                  />
                </Field>
                <Field>
                  <FieldLabel htmlFor="seniority">Seniority</FieldLabel>
                  <Input id="seniority" name="seniority" placeholder="Senior" />
                </Field>
                <Field>
                  <FieldLabel htmlFor="technology_stack">Stack</FieldLabel>
                  <Input
                    id="technology_stack"
                    name="technology_stack"
                    placeholder="React, TypeScript"
                  />
                </Field>
                <Button className="self-end" type="submit">
                  Add job
                </Button>
              </>
            )}
          </Form>
        )}
        <div className="space-y-2">
          {jobs.map((job) => (
            <div
              key={job.id}
              className="flex items-center justify-between rounded-lg border p-3"
            >
              <div>
                <Link
                  href={`/jobs/${job.id}`}
                  className="font-medium hover:underline"
                >
                  {job.title}
                </Link>
                <span className="text-muted-foreground">
                  {" "}
                  · {job.project} / {job.client}
                </span>
                <p className="text-muted-foreground text-sm">
                  {[job.seniority, job.technology_stack, job.status]
                    .filter(Boolean)
                    .join(" · ")}
                </p>
              </div>
              <Button asChild size="sm">
                <Link href={`/candidates/new?job_id=${job.id}`}>
                  Source candidate
                </Link>
              </Button>
            </div>
          ))}
        </div>
      </div>
    </AppLayout>
  )
}
