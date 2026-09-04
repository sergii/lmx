import { Form, Head } from "@inertiajs/react"
import { Bot, KeyRound, ShieldCheck, ShieldOff } from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import AppLayout from "@/layouts/app-layout"

type Membership = {
  id: string
  workspace_id: string
  user_id: string
  role: string
  active: boolean
  client_portal: boolean
}

type GrantStatus = "active" | "blocked" | "revoked"

type Grant = {
  id: string
  workspace_id: string
  issuer: string
  subject: string
  client_id: string
  principal: string
  credential: string
  actor: string
  executor: string
  client: string
  capabilities: string[]
  revoked_at: string | null
  revoked_by: string | null
  revoke_reason: string | null
  created_by: string
  created_at: string | null
  updated_at: string | null
  authorization_kind:
    "workspace_membership" | "orphaned_workspace_user" | "service_principal"
  membership: Membership | null
  workspace_capabilities: string[] | null
  effective_capabilities: string[]
  status: GrantStatus
}

const capabilityDescriptions: Record<string, string> = {
  "assess:matches": "Record match assessments",
  "read:applications": "Read application state",
  "read:candidates": "Read candidate identity and profile",
  "read:matches": "Read match analysis",
  "read:openings": "Search and inspect openings",
  "submit:openings": "Submit new opportunities",
}

function statusBadge(status: GrantStatus) {
  if (status === "revoked") {
    return <Badge variant="destructive">Revoked</Badge>
  }

  if (status === "blocked") {
    return <Badge variant="outline">Blocked by workspace</Badge>
  }

  return <Badge variant="secondary">Active</Badge>
}

function capabilityBadges(values: string[], emptyLabel = "None") {
  if (values.length === 0) {
    return <span className="text-muted-foreground text-xs">{emptyLabel}</span>
  }

  return (
    <div className="flex flex-wrap gap-1.5">
      {values.map((capability) => (
        <Badge key={capability} variant="outline" className="font-mono">
          {capability}
        </Badge>
      ))}
    </div>
  )
}

export default function AgentAccessSettings({ grants }: { grants: Grant[] }) {
  const activeCount = grants.filter((grant) => grant.status === "active").length
  const blockedCount = grants.filter(
    (grant) => grant.status === "blocked",
  ).length
  const revokedCount = grants.filter(
    (grant) => grant.status === "revoked",
  ).length

  return (
    <AppLayout
      breadcrumbs={[{ title: "Agent access", href: "/settings/agent-access" }]}
    >
      <Head title="Agent access" />

      <div className="max-w-5xl p-6">
        <div className="flex items-start gap-3">
          <span className="bg-primary/10 text-primary flex size-10 items-center justify-center rounded-xl">
            <Bot className="size-5" />
          </span>
          <div>
            <h1 className="text-xl font-semibold">Agent access</h1>
            <p className="text-muted-foreground mt-1 max-w-2xl text-sm">
              Inspect and control persisted OAuth grants used by ChatGPT,
              Claude, Codex, Hermes, and other MCP clients.
            </p>
          </div>
        </div>

        <div className="mt-8 grid gap-3 sm:grid-cols-3">
          <div className="rounded-xl border p-4">
            <p className="text-muted-foreground text-xs font-medium uppercase">
              Active
            </p>
            <p className="mt-1 text-2xl font-semibold">{activeCount}</p>
          </div>
          <div className="rounded-xl border p-4">
            <p className="text-muted-foreground text-xs font-medium uppercase">
              Blocked
            </p>
            <p className="mt-1 text-2xl font-semibold">{blockedCount}</p>
          </div>
          <div className="rounded-xl border p-4">
            <p className="text-muted-foreground text-xs font-medium uppercase">
              Revoked
            </p>
            <p className="mt-1 text-2xl font-semibold">{revokedCount}</p>
          </div>
        </div>

        <section className="bg-muted/40 mt-6 rounded-xl border p-5">
          <div className="flex items-start gap-3">
            <ShieldCheck className="text-muted-foreground mt-0.5 size-5 shrink-0" />
            <div>
              <h2 className="text-sm font-medium">Authorization composition</h2>
              <p className="text-muted-foreground mt-1 text-sm">
                The token scope is verified on every request and is not stored
                here. For workspace users, runtime access is the intersection of
                token scopes, the stored grant, and the current workspace role
                maximum.
              </p>
              <p className="text-muted-foreground mt-3 font-mono text-xs">
                token scopes ∩ stored grant ∩ workspace maximum = runtime
                capabilities
              </p>
            </div>
          </div>
        </section>

        <section className="mt-8">
          <div className="flex items-center justify-between gap-4">
            <div>
              <h2 className="font-medium">Connected identities</h2>
              <p className="text-muted-foreground mt-1 text-sm">
                Grants remain visible after revocation so their audit state is
                not lost.
              </p>
            </div>
            <Badge variant="outline">{grants.length} total</Badge>
          </div>

          {grants.length === 0 ? (
            <div className="text-muted-foreground mt-4 rounded-xl border border-dashed p-8 text-center text-sm">
              No persisted OAuth agent grants exist in this workspace yet.
            </div>
          ) : (
            <div className="mt-4 space-y-4">
              {grants.map((grant) => {
                const workspaceManaged =
                  grant.authorization_kind !== "service_principal"
                const editableCapabilities = grant.workspace_capabilities ?? []

                return (
                  <article key={grant.id} className="rounded-xl border p-5">
                    <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-2">
                          <h3 className="font-medium">{grant.client}</h3>
                          {statusBadge(grant.status)}
                          <Badge variant="outline">
                            {workspaceManaged
                              ? "Workspace user"
                              : "Service principal"}
                          </Badge>
                        </div>
                        <p className="text-muted-foreground mt-1 text-sm break-all">
                          {grant.subject} · {grant.client_id}
                        </p>
                      </div>
                      <div className="text-muted-foreground text-right text-xs">
                        <p className="font-mono">{grant.id}</p>
                        <p className="mt-1">credential: {grant.credential}</p>
                      </div>
                    </div>

                    <dl className="mt-5 grid gap-4 rounded-lg border p-4 text-sm sm:grid-cols-2">
                      <div>
                        <dt className="text-muted-foreground text-xs">
                          Issuer
                        </dt>
                        <dd className="mt-1 font-mono text-xs break-all">
                          {grant.issuer}
                        </dd>
                      </div>
                      <div>
                        <dt className="text-muted-foreground text-xs">
                          Local principal
                        </dt>
                        <dd className="mt-1 font-mono text-xs break-all">
                          {grant.principal}
                        </dd>
                      </div>
                      <div>
                        <dt className="text-muted-foreground text-xs">
                          Executor
                        </dt>
                        <dd className="mt-1 font-mono text-xs break-all">
                          {grant.executor}
                        </dd>
                      </div>
                      <div>
                        <dt className="text-muted-foreground text-xs">
                          Workspace membership
                        </dt>
                        <dd className="mt-1 text-xs">
                          {grant.membership ? (
                            <span>
                              {grant.membership.role.replaceAll("_", " ")} ·{" "}
                              {grant.membership.active ? "active" : "inactive"}
                            </span>
                          ) : grant.authorization_kind ===
                            "orphaned_workspace_user" ? (
                            "No current membership"
                          ) : (
                            "Not role-bound"
                          )}
                        </dd>
                      </div>
                    </dl>

                    <div className="mt-5 grid gap-4 lg:grid-cols-4">
                      <div>
                        <p className="text-muted-foreground text-xs font-medium">
                          Token scopes
                        </p>
                        <p className="mt-2 text-xs">Verified at runtime</p>
                      </div>
                      <div>
                        <p className="text-muted-foreground text-xs font-medium">
                          Stored grant
                        </p>
                        <div className="mt-2">
                          {capabilityBadges(grant.capabilities)}
                        </div>
                      </div>
                      <div>
                        <p className="text-muted-foreground text-xs font-medium">
                          Workspace maximum
                        </p>
                        <div className="mt-2">
                          {grant.workspace_capabilities === null
                            ? capabilityBadges([], "Not role-bound")
                            : capabilityBadges(grant.workspace_capabilities)}
                        </div>
                      </div>
                      <div>
                        <p className="text-muted-foreground text-xs font-medium">
                          Effective ceiling
                        </p>
                        <div className="mt-2">
                          {capabilityBadges(grant.effective_capabilities)}
                        </div>
                      </div>
                    </div>

                    {workspaceManaged && editableCapabilities.length > 0 && (
                      <Form
                        action={`/settings/agent-access/grants/${grant.id}/capabilities`}
                        method="patch"
                        className="mt-5 rounded-lg border p-4"
                      >
                        {({ processing }) => (
                          <>
                            <div className="flex items-center gap-2">
                              <KeyRound className="text-muted-foreground size-4" />
                              <h4 className="text-sm font-medium">
                                Stored capability ceiling
                              </h4>
                            </div>
                            <div className="mt-3 grid gap-2 sm:grid-cols-2">
                              {editableCapabilities.map((capability) => (
                                <label
                                  key={capability}
                                  className="hover:bg-muted/50 flex cursor-pointer items-start gap-3 rounded-lg border p-3"
                                >
                                  <input
                                    type="checkbox"
                                    name="capabilities[]"
                                    value={capability}
                                    defaultChecked={grant.capabilities.includes(
                                      capability,
                                    )}
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
                            <div className="mt-4 flex justify-end">
                              <Button
                                type="submit"
                                size="sm"
                                disabled={processing}
                              >
                                Save capabilities
                              </Button>
                            </div>
                          </>
                        )}
                      </Form>
                    )}

                    {grant.authorization_kind === "service_principal" && (
                      <p className="text-muted-foreground mt-5 rounded-lg border border-dashed p-4 text-xs">
                        This is a trusted service-principal grant. It is visible
                        here and can be revoked, but its capability ceiling is
                        not edited through workspace-role policy.
                      </p>
                    )}

                    {grant.status === "blocked" && (
                      <div className="mt-5 flex items-start gap-2 rounded-lg border p-4 text-sm">
                        <ShieldOff className="text-muted-foreground mt-0.5 size-4 shrink-0" />
                        <p>
                          The stored grant still exists, but current workspace
                          authorization reduces its effective ceiling to zero.
                        </p>
                      </div>
                    )}

                    <div className="mt-5 border-t pt-4">
                      {grant.status === "revoked" ? (
                        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                          <div className="text-muted-foreground text-xs">
                            <p>
                              Revoked
                              {grant.revoked_at
                                ? ` ${new Date(grant.revoked_at).toLocaleString()}`
                                : ""}
                            </p>
                            {grant.revoke_reason && (
                              <p className="mt-1">{grant.revoke_reason}</p>
                            )}
                          </div>
                          <Form
                            action={`/settings/agent-access/grants/${grant.id}/restore`}
                            method="post"
                          >
                            {({ processing }) => (
                              <Button
                                type="submit"
                                size="sm"
                                variant="outline"
                                disabled={processing}
                              >
                                Restore access
                              </Button>
                            )}
                          </Form>
                        </div>
                      ) : (
                        <Form
                          action={`/settings/agent-access/grants/${grant.id}/revoke`}
                          method="post"
                        >
                          {({ processing }) => (
                            <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
                              <div className="w-full max-w-md">
                                <label
                                  htmlFor={`reason-${grant.id}`}
                                  className="text-muted-foreground text-xs"
                                >
                                  Optional revocation reason
                                </label>
                                <Input
                                  id={`reason-${grant.id}`}
                                  name="reason"
                                  className="mt-1"
                                  placeholder="Agent disconnected, device retired, access review..."
                                />
                              </div>
                              <Button
                                type="submit"
                                size="sm"
                                variant="destructive"
                                disabled={processing}
                              >
                                Revoke access
                              </Button>
                            </div>
                          )}
                        </Form>
                      )}
                    </div>
                  </article>
                )
              })}
            </div>
          )}
        </section>
      </div>
    </AppLayout>
  )
}
