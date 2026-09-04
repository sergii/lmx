import { Head, Link, router } from "@inertiajs/react"
import { ArrowLeft, Link2, Plus, Send } from "lucide-react"
import { useState } from "react"

import Heading from "@/components/heading"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import AppLayout from "@/layouts/app-layout"

interface FormState {
  title: string
  company_name: string
  url: string
  location: string
  remote_policy: string
  compensation: string
  notes: string
}

const initialForm: FormState = {
  title: "",
  company_name: "",
  url: "",
  location: "",
  remote_policy: "",
  compensation: "",
  notes: "",
}

export default function NewOpening() {
  const [form, setForm] = useState(initialForm)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  function update(field: keyof FormState, value: string) {
    setForm((current) => ({ ...current, [field]: value }))
  }

  function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSubmitting(true)
    setError(null)

    router.post(
      "/openings",
      {
        ...form,
        idempotency_key: crypto.randomUUID(),
      },
      {
        onError: () => {
          setError("Could not add this opening. Check the title and URL.")
        },
        onFinish: () => setSubmitting(false),
      },
    )
  }

  return (
    <AppLayout
      breadcrumbs={[
        { title: "Openings", href: "/openings" },
        { title: "Add opening", href: "/openings/new" },
      ]}
    >
      <Head title="Add opening" />

      <div className="mx-auto w-full max-w-3xl space-y-6 p-6">
        <div>
          <Button asChild variant="ghost" size="sm" className="mb-3 -ml-3">
            <Link href="/openings">
              <ArrowLeft className="size-4" />
              Back to openings
            </Link>
          </Button>
          <Heading
            title="Add opening"
            description="Paste a vacancy URL or capture an opportunity that has no public URL. Both enter the same canonical Market Catalog workflow."
          />
        </div>

        <div className="grid gap-3 sm:grid-cols-2">
          <div className="bg-card rounded-xl border p-4">
            <div className="flex items-center gap-2 font-medium">
              <Link2 className="size-4" />
              With URL
            </div>
            <p className="text-muted-foreground mt-2 text-sm">
              The URL becomes publication evidence. Known job sites retain their
              source identity; other sites are recorded as generic web evidence.
            </p>
          </div>
          <div className="bg-card rounded-xl border p-4">
            <div className="flex items-center gap-2 font-medium">
              <Plus className="size-4" />
              Without URL
            </div>
            <p className="text-muted-foreground mt-2 text-sm">
              Useful for recruiter messages, referrals, private roles, or
              opportunities you only know from a conversation.
            </p>
          </div>
        </div>

        <form onSubmit={submit} className="bg-card space-y-5 rounded-xl border p-5">
          <Field label="Role title" required>
            <Input
              value={form.title}
              onChange={(event) => update("title", event.target.value)}
              placeholder="Senior Ruby Engineer"
              required
              autoFocus
            />
          </Field>

          <div className="grid gap-5 sm:grid-cols-2">
            <Field label="Company">
              <Input
                value={form.company_name}
                onChange={(event) => update("company_name", event.target.value)}
                placeholder="Acme"
              />
            </Field>
            <Field label="Vacancy URL" hint="Optional">
              <Input
                type="url"
                value={form.url}
                onChange={(event) => update("url", event.target.value)}
                placeholder="https://…"
              />
            </Field>
          </div>

          <div className="grid gap-5 sm:grid-cols-2">
            <Field label="Location" hint="Optional">
              <Input
                value={form.location}
                onChange={(event) => update("location", event.target.value)}
                placeholder="Kyiv / Europe / Worldwide"
              />
            </Field>
            <Field label="Remote policy" hint="Optional">
              <Input
                value={form.remote_policy}
                onChange={(event) => update("remote_policy", event.target.value)}
                placeholder="Remote, hybrid, on-site…"
              />
            </Field>
          </div>

          <Field label="Compensation" hint="Keep the original wording">
            <Input
              value={form.compensation}
              onChange={(event) => update("compensation", event.target.value)}
              placeholder="$6,000-$7,000/month, gross"
            />
          </Field>

          <Field label="Notes" hint="Optional private capture context">
            <textarea
              value={form.notes}
              onChange={(event) => update("notes", event.target.value)}
              placeholder="Recruiter message, referral context, why this may be interesting…"
              rows={5}
              className="border-input placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-ring/50 w-full resize-y rounded-md border bg-transparent px-3 py-2 text-sm shadow-xs outline-none focus-visible:ring-[3px]"
            />
          </Field>

          {error && (
            <p className="text-destructive text-sm" role="alert">
              {error}
            </p>
          )}

          <div className="flex flex-wrap items-center justify-between gap-3 border-t pt-5">
            <p className="text-muted-foreground max-w-lg text-xs leading-relaxed">
              Manual ingress is provenance, not a new acquisition source. The
              accepted opening remains canonical Market Catalog state and the
              submission is recorded through the durable command/event boundary.
            </p>
            <Button type="submit" disabled={submitting || form.title.trim() === ""}>
              <Send className="size-4" />
              {submitting ? "Adding…" : "Add opening"}
            </Button>
          </div>
        </form>
      </div>
    </AppLayout>
  )
}

function Field({
  label,
  hint,
  required = false,
  children,
}: {
  label: string
  hint?: string
  required?: boolean
  children: React.ReactNode
}) {
  return (
    <label className="block space-y-2">
      <span className="flex items-center gap-2 text-sm font-medium">
        {label}
        {required && <span className="text-destructive">*</span>}
        {hint && (
          <span className="text-muted-foreground text-xs font-normal">{hint}</span>
        )}
      </span>
      {children}
    </label>
  )
}
