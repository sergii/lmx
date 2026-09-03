import { Form, Head, Link } from "@inertiajs/react"
import Heading from "@/components/heading"
import { Button } from "@/components/ui/button"
import { Field, FieldError, FieldLabel } from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import AppLayout from "@/layouts/app-layout"

export default function ClientCompanies({
  clients,
}: {
  clients: { id: string; name: string }[]
}) {
  return (
    <AppLayout breadcrumbs={[{ title: "Clients", href: "/client_companies" }]}>
      <Head title="Clients" />
      <div className="max-w-3xl p-6">
        <Heading
          title="Clients"
          description="Companies your workspace recruits for."
        />
        <Form
          action="/client_companies"
          method="post"
          className="mb-8 flex gap-3"
        >
          {({ errors }) => (
            <>
              <Field className="flex-1">
                <FieldLabel htmlFor="name">Client company</FieldLabel>
                <Input id="name" name="name" required placeholder="Acme Inc." />
                <FieldError
                  errors={errors.name?.map((message) => ({ message }))}
                />
              </Field>
              <Button className="self-end" type="submit">
                Add client
              </Button>
            </>
          )}
        </Form>
        <div className="space-y-2">
          {clients.map((client) => (
            <div key={client.id} className="rounded-lg border p-3">
              {client.name}
            </div>
          ))}
        </div>
        <Button asChild variant="link" className="mt-4 px-0">
          <Link href="/projects">Continue to projects</Link>
        </Button>
      </div>
    </AppLayout>
  )
}
