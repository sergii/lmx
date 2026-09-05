import { Form, Head } from "@inertiajs/react"
import { ArrowLeft, Bot, Clock3, KeyRound, ShieldCheck } from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import AppLayout from "@/layouts/app-layout"

type Pairing = {
  token: string
  issuer: string
  subject: string
  client_id: string
  resource: string
  scopes: string[]
  pairable_capabilities: string[]
  issued_at: string
  expires_at: string
}

type Member = {
  id: string
  user_id: string
  name: string
  email: string
  role: string
}

const capabilityDescriptions: Record<string, string> = {
  "assess:matches": "Record match assessments",
  "read:applications": "Read application state",
  "read:candidates": "Read candidate identity and profile",
  "read:matches": "Read match analysis",
  "read:openings": "Search and inspect openings",
  "submit:openings": "Submit new opportunities",
}

export default function PairMcpOauthAgent({
  pairing,
  members,
}: {
  pairing: Pairing
  members: Member[]
}) {
  const expiresAt = new Date(pairing.expires_at)
  const unsupportedScopes = pairing.scopes.filter(
    (scope) => !pairing.pairable_capabilities.includes(scope),
  )

  return (
    <AppLayout
      breadcrumbs={[
        { title: "Agent access", href: "/settings/agent-access" },
        {
          title: "Pair OAuth agent",
          href: "/settings/agent-access/pair",
        },
      ]}
    >
      <Head title="Pair OAuth agent" />

      <div className="max-w-4xl p-6">
        <a
          href="/settings/agent-access"
          className="text-muted-foreground hover:text-foreground inline-flex items-center gap-1.5 text-sm"
        >
          <ArrowLeft className="size-4" />
          Agent access
        </a>

        <div className="mt-6 flex items-start gap-3">
          <span className="bg-primary/10 text-primary flex size-10 items-center justify-center rounded-xl">
            <Bot className="size-5" />
          </span>
          <div>
            <h1 className="text-xl font-semibold">Authorize MCP agent</h1>
            <p className="text-muted-foreground mt-1 max-w-2xl text-sm">
              LMX has already verified this OAuth access token with the
              configured authorization server. Choose which workspace identity
              it may act as and grant only the capabilities you want to allow.
            </p>
          </div>
        </div>

        <section className="mt-8 rounded-xl border p-5">
          <div className="flex flex-wrap items-center gap-2">
            <Badge variant="secondary">Verified OAuth identity</Badge>
            <div className="text-muted-foreground flex items-center gap-1.5 text-xs">
              <Clock3 className="size-3.5" />
              Expires {expiresAt.toLocaleString()}
            </div>
          </div>

          <dl className="mt-5 grid gap-4 text-sm sm:grid-cols-2">
            <div>
              <dt className="text-muted-foreground text-xs">Issuer</dt>
              <dd className="mt-1 break-all font-mono text-xs">
                {pairing.issuer}
              </dd>
            </div>
            <div>
              <dt className="text-muted-foreground text-xs">OAuth client</dt>
              <dd className="mt-1 break-all font-mono text-xs">
                {pairing.client_id}
              </dd>
            </div>
            <div>
              <dt className="text-muted-foreground text-xs">
                External subject
              </dt>
              <dd className="mt-1 break-all font-mono text-xs">
                {pairing.subject}
              </dd>
            </div>
            <div>
              <dt className="text-muted-foreground text-xs">MCP resource</dt>
              <dd className="mt-1 break-all font-mono text-xs">
                {pairing.resource}
              </dd>
            </div>
          </dl>
        </section>

        <section className="bg-muted/40 mt-5 rounded-xl border p-5">
          <div className="flex items-start gap-3">
            <ShieldCheck className="text-muted-foreground mt-0.5 size-5 shrink-0" />
            <div>
              <h2 className="text-sm font-medium">Authorization is narrowing</h2>
              <p className="text-muted-foreground mt-1 text-sm">
                Approval cannot add privileges the verified token did not ask
                for. Runtime access will still be intersected with this stored
                grant and the member&apos;s current Workspace role on every MCP
                request.
              </p>
            </div>
          </div>
        </section>

        <Form
          action="/settings/agent-access/pair"
          method="post"
          className="mt-6 space-y-6"
        >
          {({ processing }) => (
            <>
              <input type="hidden" name="pairing_token" value={pairing.token} />

              <section className="rounded-xl border p-5">
                <div className="flex items-center gap-2">
                  <KeyRound className="text-muted-foreground size-4" />
                  <h2 className="font-medium">Act as workspace member</h2>
                </div>
                <p className="text-muted-foreground mt-1 text-sm">
                  The selected member becomes the trusted local principal for
                  this external OAuth identity.
                </p>

                <label className="mt-4 block">
                  <span className="text-muted-foreground text-xs">
                    Workspace member
                  </span>
                  <select
                    name="membership_id"
                    required
                    defaultValue=""
                    className="border-input bg-background mt-1 h-10 w-full rounded-md border px-3 text-sm shadow-xs outline-none focus:ring-2"
                  >
                    <option value="" disabled>
                      Select a member
                    </option>
                    {members.map((member) => (
                      <option key={member.id} value={member.id}>
                        {member.name} · {member.email} ·{" "}
                        {member.role.replaceAll("_", " ")}
                      </option>
                    ))}
                  </select>
                </label>
              </section>

              <section className="rounded-xl border p-5">
                <h2 className="font-medium">Requested OAuth scopes</h2>
                <div className="mt-3 flex flex-wrap gap-1.5">
                  {pairing.scopes.map((scope) => (
                    <Badge key={scope} variant="outline" className="font-mono">
                      {scope}
                    </Badge>
                  ))}
                </div>

                {unsupportedScopes.length > 0 && (
                  <p className="text-muted-foreground mt-3 text-xs">
                    Some requested scopes are not current LMX MCP capabilities
                    and cannot be granted here: {unsupportedScopes.join(", ")}.
                  </p>
                )}
              </section>

              <section className="rounded-xl border p-5">
                <h2 className="font-medium">Allow capabilities</h2>
                <p className="text-muted-foreground mt-1 text-sm">
                  Nothing is selected by default. Choose the smallest useful
                  capability set for this agent.
                </p>

                {pairing.pairable_capabilities.length === 0 ? (
                  <p className="text-muted-foreground mt-4 rounded-lg border border-dashed p-4 text-sm">
                    This token requested no LMX capabilities that can be paired.
                  </p>
                ) : (
                  <div className="mt-4 grid gap-2 sm:grid-cols-2">
                    {pairing.pairable_capabilities.map((capability) => (
                      <label
                        key={capability}
                        className="hover:bg-muted/50 flex cursor-pointer items-start gap-3 rounded-lg border p-3"
                      >
                        <input
                          type="checkbox"
                          name="capabilities[]"
                          value={capability}
                          className="border-input mt-0.5 size-4 rounded"
                        />
                        <span>
                          <span className="block font-mono text-xs">
                            {capability}
                          </span>
                          <span className="text-muted-foreground mt-0.5 block text-xs">
                            {capabilityDescriptions[capability] ??
                              "Integration capability"}
                          </span>
                        </span>
                      </label>
                    ))}
                  </div>
                )}
              </section>

              <div className="flex items-center justify-between gap-4 border-t pt-5">
                <p className="text-muted-foreground max-w-xl text-xs">
                  The pairing link is short-lived and contains no OAuth bearer
                  token. The external identity can only be paired once.
                </p>
                <Button
                  type="submit"
                  disabled={
                    processing || pairing.pairable_capabilities.length === 0
                  }
                >
                  Authorize agent
                </Button>
              </div>
            </>
          )}
        </Form>
      </div>
    </AppLayout>
  )
}
