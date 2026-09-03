import { Form, Head, Link } from "@inertiajs/react"

import Heading from "@/components/heading"
import { Button } from "@/components/ui/button"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import AppLayout from "@/layouts/app-layout"

interface ClientApplication {
  id: string
  stage: string
  decision_open: boolean
  decision: { outcome: string; note: string | null; decided_at: string } | null
  role: string
  project: string
  candidate: { name: string; skills: string[] }
}

export default function ClientApplicationShow({
  application,
  can_decide,
}: {
  application: ClientApplication
  can_decide: boolean
}) {
  const decision = application.decision

  return (
    <AppLayout
      breadcrumbs={[
        { title: "Presented candidates", href: "/client/applications" },
        {
          title: application.candidate.name,
          href: `/client/applications/${application.id}`,
        },
      ]}
    >
      <Head title={application.candidate.name} />
      <div className="max-w-3xl p-6">
        <Link
          href="/client/applications"
          className="text-muted-foreground text-sm hover:underline"
        >
          ← Presented candidates
        </Link>
        <div className="mt-5 rounded-xl border p-6">
          <Heading
            title={application.candidate.name}
            description={`${application.role} · ${application.project}`}
          />
          <dl className="mt-6 space-y-4">
            <div>
              <dt className="text-muted-foreground text-xs">Stage</dt>
              <dd className="capitalize">
                {application.stage.replaceAll("_", " ")}
              </dd>
            </div>
            <div>
              <dt className="text-muted-foreground text-xs">Skills</dt>
              <dd>
                {application.candidate.skills.length > 0
                  ? application.candidate.skills.join(", ")
                  : "Not provided"}
              </dd>
            </div>
          </dl>
        </div>

        {decision ? (
          <section className="mt-5 rounded-xl border p-6">
            <h2 className="font-semibold">Client decision</h2>
            <p className="mt-2 capitalize">{decision.outcome}</p>
            {decision.note && (
              <p className="text-muted-foreground mt-2 text-sm whitespace-pre-wrap">
                {decision.note}
              </p>
            )}
          </section>
        ) : can_decide && application.decision_open ? (
          <section className="mt-5 rounded-xl border p-6">
            <h2 className="font-semibold">Make a decision</h2>
            <p className="text-muted-foreground mt-1 text-sm">
              Your decision is shared with the recruiting team and creates their
              follow-up task.
            </p>
            <Form
              action={`/client/applications/${application.id}/decision`}
              method="post"
              className="mt-4"
            >
              {({ processing, errors }) => (
                <FieldGroup>
                  <Field>
                    <FieldLabel htmlFor="note">
                      Note for the recruiting team (optional)
                    </FieldLabel>
                    <textarea
                      id="note"
                      name="note"
                      className="border-input min-h-24 w-full rounded-md border bg-transparent p-3 text-sm"
                      placeholder="Why this candidate is a fit, or why you are passing."
                    />
                    <FieldError
                      errors={errors.decision?.map((message) => ({ message }))}
                    />
                  </Field>
                  <div className="flex flex-wrap gap-3">
                    <Button
                      type="submit"
                      name="decision"
                      value="accepted"
                      disabled={processing}
                    >
                      Accept candidate
                    </Button>
                    <Button
                      type="submit"
                      name="decision"
                      value="rejected"
                      variant="outline"
                      disabled={processing}
                    >
                      Pass on candidate
                    </Button>
                  </div>
                </FieldGroup>
              )}
            </Form>
          </section>
        ) : (
          <p className="text-muted-foreground mt-5 text-sm">
            A hiring manager can record the client decision when the review is
            complete.
          </p>
        )}
      </div>
    </AppLayout>
  )
}
