import { Form } from "@inertiajs/react"
import { format } from "date-fns"
import { Bookmark, CircleSlash2, Send } from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"

interface ApplicationAttempt {
  id: string
  attempt_number: number
  applied_at: string | null
  current_stage: string
  channel: string | null
  next_action: string | null
  next_action_at: string | null
}

interface PersonalActionsProps {
  openingId: string
  candidatePresent: boolean
  state: string | null
  changedAt: string | null
  application: ApplicationAttempt | null
}

function actionVariant(active: boolean) {
  return active ? "default" : "outline"
}

function appliedAt(value: string | null) {
  return value ? format(new Date(value), "MMM d, yyyy · HH:mm") : "Unknown time"
}

export default function PersonalActions({
  openingId,
  candidatePresent,
  state,
  changedAt,
  application,
}: PersonalActionsProps) {
  const applied = state === "applied" || application !== null

  return (
    <section className="bg-card border p-5">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="font-semibold">Personal workflow</h2>
            {state && <Badge variant="secondary">{state}</Badge>}
          </div>
          <p className="text-muted-foreground mt-1 max-w-2xl text-sm leading-relaxed">
            Save and ignore are personal handling states. Mark applied only
            after you actually submit an application; it records an LMX
            application attempt and does not submit the employer form for you.
          </p>
          {!candidatePresent && (
            <p className="text-destructive mt-2 text-sm">
              Complete your candidate profile before using Personal CRM actions.
            </p>
          )}
          {application && (
            <p className="text-muted-foreground mt-2 text-sm">
              Applied {appliedAt(application.applied_at)} · attempt #
              {application.attempt_number} · stage {application.current_stage}
            </p>
          )}
          {!application && changedAt && (
            <p className="text-muted-foreground mt-2 text-xs">
              Personal state updated {appliedAt(changedAt)}
            </p>
          )}
        </div>

        <div className="flex flex-wrap gap-2">
          <Form action={`/openings/${openingId}/save`} method="post">
            {({ processing }) => (
              <Button
                type="submit"
                variant={actionVariant(state === "saved")}
                disabled={!candidatePresent || applied || processing}
              >
                <Bookmark className="size-4" />
                Save
              </Button>
            )}
          </Form>

          <Form action={`/openings/${openingId}/ignore`} method="post">
            {({ processing }) => (
              <Button
                type="submit"
                variant={actionVariant(state === "ignored")}
                disabled={!candidatePresent || applied || processing}
              >
                <CircleSlash2 className="size-4" />
                Ignore
              </Button>
            )}
          </Form>

          <Form action={`/openings/${openingId}/apply`} method="post">
            {({ processing }) => (
              <Button
                type="submit"
                disabled={!candidatePresent || applied || processing}
              >
                <Send className="size-4" />
                {applied ? "Applied" : "Mark applied"}
              </Button>
            )}
          </Form>
        </div>
      </div>
    </section>
  )
}
