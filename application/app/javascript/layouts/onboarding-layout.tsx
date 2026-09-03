import { Link } from "@inertiajs/react"
import { Check, UsersRound } from "lucide-react"
import type { PropsWithChildren, ReactNode } from "react"

import AppLogoIcon from "@/components/app-logo-icon"
import { cn } from "@/lib/utils"
import { home } from "@/routes"

const steps = ["Your profile", "Workspace", "Recruiting setup", "Team"]

export default function OnboardingLayout({
  children,
  step,
  title,
  description,
}: PropsWithChildren<{
  step: number
  title: string
  description: string
}>) {
  return (
    <div className="bg-background min-h-dvh px-4 py-6 sm:px-8 lg:px-12">
      <header className="mx-auto flex w-full max-w-6xl items-center justify-between py-3">
        <Link
          href={home()}
          className="flex items-center gap-2 text-lg font-semibold"
        >
          <span className="bg-foreground text-background flex size-8 items-center justify-center rounded-lg">
            <AppLogoIcon className="size-5 fill-current" />
          </span>
          Hire.do
        </Link>
        <span className="text-muted-foreground text-sm">Workspace setup</span>
      </header>

      <main className="bg-card mx-auto mt-6 grid w-full max-w-6xl overflow-hidden rounded-3xl border shadow-sm lg:min-h-[680px] lg:grid-cols-[minmax(0,0.95fr)_minmax(0,1.05fr)]">
        <section className="flex min-h-[560px] flex-col px-6 py-8 sm:px-12 sm:py-12">
          <ol
            className="mb-12 flex items-center gap-2"
            aria-label="Onboarding progress"
          >
            {steps.map((label, index) => {
              const number = index + 1
              const complete = number < step
              const active = number === step

              return (
                <li key={label} className="flex items-center gap-2">
                  <span
                    className={cn(
                      "flex size-7 items-center justify-center rounded-full border text-xs font-medium",
                      complete &&
                        "border-primary bg-primary text-primary-foreground",
                      active && "border-primary text-primary",
                      !complete && !active && "text-muted-foreground",
                    )}
                    aria-label={`${label}${complete ? ", completed" : active ? ", current" : ""}`}
                  >
                    {complete ? <Check className="size-3.5" /> : number}
                  </span>
                  {index < steps.length - 1 && (
                    <span className="bg-border h-px w-5 sm:w-8" />
                  )}
                </li>
              )
            })}
          </ol>

          <div className="max-w-md">
            <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
            <p className="text-muted-foreground mt-3 text-sm leading-6">
              {description}
            </p>
          </div>

          <div className="mt-8 max-w-md">{children}</div>
        </section>

        <ProductPreview />
      </main>
    </div>
  )
}

function ProductPreview(): ReactNode {
  return (
    <aside className="from-muted/70 to-background relative hidden overflow-hidden border-l bg-gradient-to-br p-8 lg:block">
      <div className="bg-primary absolute inset-x-0 top-0 h-1" />
      <div className="bg-primary/10 absolute top-24 -right-20 size-64 rounded-full blur-3xl" />
      <div className="bg-background relative mx-auto mt-16 max-w-md rounded-2xl border p-4 shadow-xl">
        <div className="flex items-center justify-between border-b pb-4">
          <div className="flex items-center gap-2 font-semibold">
            <span className="bg-primary text-primary-foreground flex size-7 items-center justify-center rounded-md text-xs">
              H
            </span>
            Your workspace
          </div>
          <UsersRound className="text-muted-foreground size-5" />
        </div>
        <div className="mt-4 grid grid-cols-[110px_1fr] gap-4 text-xs">
          <div className="text-muted-foreground space-y-3 border-r pr-3">
            <p className="bg-muted text-foreground rounded-md px-2 py-1.5 font-medium">
              Candidates
            </p>
            <p className="px-2">Clients</p>
            <p className="px-2">Projects</p>
            <p className="px-2">Pipeline</p>
          </div>
          <div>
            <div className="flex items-center justify-between">
              <p className="font-semibold">Talent pipeline</p>
              <span className="bg-primary/10 text-primary rounded px-2 py-1">
                New candidate
              </span>
            </div>
            <div className="mt-4 grid grid-cols-3 gap-2">
              {["Sourced", "Review", "Presented"].map((column, index) => (
                <div key={column} className="bg-muted/60 rounded-lg p-2">
                  <p className="text-[10px] font-medium">{column}</p>
                  <div
                    className={cn(
                      "bg-background mt-3 h-16 rounded-md shadow-sm",
                      index === 2 && "border-primary/30 border",
                    )}
                  />
                  {index === 1 && (
                    <div className="bg-background mt-2 h-10 rounded-md shadow-sm" />
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
      <p className="text-muted-foreground relative mx-auto mt-8 max-w-sm text-center text-sm leading-6">
        Build a shared view of your clients, roles, and candidate pipeline from
        the first day.
      </p>
    </aside>
  )
}
