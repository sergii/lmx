import { Form, Head } from "@inertiajs/react"
import { ShieldCheck, UsersRound } from "lucide-react"

import { Button } from "@/components/ui/button"
import OnboardingLayout from "@/layouts/onboarding-layout"

export default function Team({ workspace_name }: { workspace_name: string }) {
  return (
    <OnboardingLayout
      step={4}
      title="Your workspace is ready"
      description={`You are the workspace admin for ${workspace_name}. Start with your candidate pipeline now; invite teammates whenever you are ready.`}
    >
      <Head title="Workspace ready" />
      <div className="bg-muted/30 space-y-4 rounded-2xl border p-5 text-sm">
        <div className="flex gap-3">
          <span className="bg-primary/10 text-primary flex size-9 shrink-0 items-center justify-center rounded-lg">
            <ShieldCheck className="size-5" />
          </span>
          <div>
            <p className="font-medium">Workspace admin access</p>
            <p className="text-muted-foreground mt-1 leading-5">
              You can manage workspace settings and invite your recruiting team.
            </p>
          </div>
        </div>
        <div className="flex gap-3">
          <span className="bg-primary/10 text-primary flex size-9 shrink-0 items-center justify-center rounded-lg">
            <UsersRound className="size-5" />
          </span>
          <div>
            <p className="font-medium">Invite teammates next</p>
            <p className="text-muted-foreground mt-1 leading-5">
              Team invitations and mailbox connections will be added from
              workspace settings, so you can begin without granting external
              access.
            </p>
          </div>
        </div>
      </div>
      <Form action="/onboarding/complete" method="post" className="mt-6">
        {({ processing }) => (
          <Button type="submit" className="w-full" disabled={processing}>
            Open workspace
          </Button>
        )}
      </Form>
    </OnboardingLayout>
  )
}
