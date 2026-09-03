import { Head, Link } from "@inertiajs/react"
import {
  ArrowUp,
  BarChart3,
  CalendarDays,
  CalendarCheck2,
  CheckSquare,
  CirclePlus,
  FolderKanban,
  ListTodo,
  Mail,
  Paperclip,
  Search,
  UsersRound,
} from "lucide-react"
import { FormEvent, useState } from "react"

import { Button } from "@/components/ui/button"
import OutlookCalendarIcon from "@/components/outlook-calendar-icon"
import AppLayout from "@/layouts/app-layout"
import type { BreadcrumbItem } from "@/types"

const breadcrumbs: BreadcrumbItem[] = [{ title: "Home", href: "/home" }]

type Stats = {
  candidates: number
  open_jobs: number
  presented: number
  clients: number
  tasks_due_today: number
}
type Candidate = {
  id: string
  name: string
  skills: string[]
  created_at: string
}
type Task = { id: string; title: string }
type Project = { id: string; name: string; client_name: string }

export default function Dashboard({
  stats,
  recent_candidates,
  tasks_due_today,
  projects,
}: {
  stats: Stats
  recent_candidates: Candidate[]
  tasks_due_today: Task[]
  projects: Project[]
}) {
  const [message, setMessage] = useState("")
  const [assistantMessage, setAssistantMessage] = useState<string | null>(null)
  const [projectId, setProjectId] = useState("workspace")
  const date = new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
  }).format(new Date())

  const askAssistant = (event: FormEvent) => {
    event.preventDefault()
    if (!message.trim()) return

    const project = projects.find((item) => item.id === projectId)
    const scope = project
      ? `${project.name} for ${project.client_name}`
      : "the whole workspace"

    setAssistantMessage(
      `The Hire.do assistant is ready to use ${scope} as context. Connect an AI provider to answer this request with your recruiting data.`,
    )
    setMessage("")
  }

  const usePrompt = (prompt: string) => {
    setMessage(prompt)
    setAssistantMessage(null)
  }

  return (
    <AppLayout breadcrumbs={breadcrumbs}>
      <Head title="Home" />
      <main className="mx-auto w-full max-w-6xl px-6 py-12 lg:py-16">
        <section className="mx-auto max-w-4xl">
          <h1 className="text-center text-3xl font-semibold tracking-tight sm:text-4xl">
            What can I help you work on?
          </h1>

          <form
            onSubmit={askAssistant}
            className="bg-card mt-10 overflow-hidden rounded-[28px] border shadow-[0_20px_60px_-28px_rgb(0_0_0_/_0.26)]"
          >
            <textarea
              aria-label="Ask Hire.do assistant"
              value={message}
              onChange={(event) => setMessage(event.target.value)}
              placeholder="Ask anything about recruiting…"
              className="placeholder:text-muted-foreground min-h-40 w-full resize-none bg-transparent px-6 py-5 text-base outline-none sm:min-h-48"
            />
            <div className="bg-muted/20 flex flex-wrap items-center gap-2 border-t px-3 py-3 sm:px-4">
              <Button
                type="button"
                variant="ghost"
                size="icon"
                disabled
                title="Adding files as AI context is coming soon"
                aria-label="Attach context (coming soon)"
              >
                <Paperclip />
              </Button>
              <label className="hover:bg-muted text-muted-foreground flex h-9 max-w-full cursor-pointer items-center gap-2 rounded-lg px-3 text-sm transition-colors">
                <FolderKanban className="size-4 shrink-0" />
                <span className="sr-only">Choose analysis scope</span>
                <select
                  value={projectId}
                  onChange={(event) => setProjectId(event.target.value)}
                  className="max-w-52 cursor-pointer appearance-none bg-transparent pr-1 outline-none sm:max-w-72"
                  aria-label="Choose project or whole workspace"
                >
                  <option value="workspace">Whole workspace</option>
                  {projects.map((project) => (
                    <option key={project.id} value={project.id}>
                      {project.client_name} · {project.name}
                    </option>
                  ))}
                </select>
              </label>
              <span className="text-muted-foreground hidden text-xs sm:inline">
                Project context
              </span>
              <Button
                type="submit"
                size="icon"
                className="ml-auto rounded-full"
                disabled={!message.trim()}
                aria-label="Send request to Hire.do assistant"
              >
                <ArrowUp />
              </Button>
            </div>
          </form>
          {assistantMessage && (
            <p className="bg-muted/60 text-muted-foreground mt-3 rounded-2xl px-4 py-3 text-sm">
              {assistantMessage}
            </p>
          )}

          <div className="mt-9 grid gap-3 sm:grid-cols-3">
            <AssistantAction
              icon={BarChart3}
              title="Summarize the hiring pipeline"
              onClick={() =>
                usePrompt(
                  "Summarize the hiring pipeline and highlight the next decisions.",
                )
              }
            />
            <AssistantAction
              icon={Mail}
              title="Draft recruiter follow-ups"
              onClick={() =>
                usePrompt(
                  "Draft follow-up messages for candidates who need a response.",
                )
              }
            />
            <AssistantAction
              icon={CalendarCheck2}
              title="Prepare upcoming interviews"
              onClick={() =>
                usePrompt("Prepare me for my upcoming candidate interviews.")
              }
            />
          </div>
        </section>

        <section className="mt-16">
          <div className="flex items-center justify-between">
            <h2 className="font-medium">Calendar and meeting context</h2>
            <span className="text-muted-foreground text-sm">Today, {date}</span>
          </div>
          <div className="mt-5 flex min-h-44 flex-col items-center justify-center rounded-2xl border border-dashed px-6 text-center">
            <CalendarDays className="text-muted-foreground size-6" />
            <h3 className="mt-3 font-medium">
              Turn interviews into hiring context
            </h3>
            <p className="text-muted-foreground mt-1 max-w-md text-sm">
              Connect a calendar to surface candidate interviews and recruitment
              follow-ups here.
            </p>
            <div className="mt-5 flex flex-wrap justify-center gap-2">
              <Button variant="outline" size="sm" disabled>
                Connect Google Calendar
              </Button>
              <Button variant="outline" size="sm" disabled>
                <OutlookCalendarIcon className="size-4" />
                Connect Outlook Calendar
              </Button>
            </div>
            <p className="text-muted-foreground mt-3 text-xs">
              OAuth connection setup is the next integration step.
            </p>
          </div>
        </section>

        <section className="mt-14 grid gap-10 lg:grid-cols-[minmax(0,1fr)_300px]">
          <div>
            <div className="flex items-center justify-between">
              <h2 className="font-medium">Tasks</h2>
              <Link
                href="/tasks"
                className="text-muted-foreground hover:text-foreground text-sm"
              >
                View all
              </Link>
            </div>
            {tasks_due_today.length === 0 ? (
              <div className="mt-4 rounded-2xl border p-8 text-center">
                <ListTodo className="text-muted-foreground mx-auto size-6" />
                <p className="mt-3 font-medium">No reminders due today</p>
                <p className="text-muted-foreground mt-1 text-sm">
                  Create a task to remember a recruiter follow-up or hiring
                  action.
                </p>
                <Button asChild className="mt-4" size="sm">
                  <Link href="/tasks">
                    <CirclePlus /> New task
                  </Link>
                </Button>
              </div>
            ) : (
              <div className="mt-4 overflow-hidden rounded-2xl border">
                {tasks_due_today.map((task) => (
                  <Link
                    key={task.id}
                    href="/tasks"
                    className="hover:bg-muted/50 flex items-center gap-3 border-b px-4 py-3 text-sm last:border-b-0"
                  >
                    <CheckSquare className="text-muted-foreground size-4" />
                    {task.title}
                  </Link>
                ))}
              </div>
            )}

            <div className="mt-10 flex items-center justify-between">
              <h2 className="font-medium">Recently added candidates</h2>
              <Link
                href="/candidates"
                className="text-muted-foreground hover:text-foreground text-sm"
              >
                View all
              </Link>
            </div>
            {recent_candidates.length === 0 ? (
              <div className="mt-4 rounded-2xl border p-8 text-center">
                <UsersRound className="text-muted-foreground mx-auto size-6" />
                <p className="mt-3 font-medium">Start your talent pool</p>
                <Button asChild className="mt-4" size="sm">
                  <Link href="/candidates/new">
                    <CirclePlus /> Add candidate
                  </Link>
                </Button>
              </div>
            ) : (
              <div className="mt-4 overflow-hidden rounded-2xl border">
                {recent_candidates.map((candidate) => (
                  <Link
                    key={candidate.id}
                    href={`/candidates/${candidate.id}`}
                    className="hover:bg-muted/50 flex items-center justify-between gap-4 border-b px-4 py-3 text-sm last:border-b-0"
                  >
                    <span className="flex min-w-0 items-center gap-3">
                      <span className="bg-primary/10 text-primary flex size-8 shrink-0 items-center justify-center rounded-full font-medium">
                        {candidate.name.slice(0, 1)}
                      </span>
                      <span className="min-w-0">
                        <span className="block truncate font-medium">
                          {candidate.name}
                        </span>
                        <span className="text-muted-foreground block truncate text-xs">
                          {candidate.skills.join(", ") || "Talent pool"}
                        </span>
                      </span>
                    </span>
                    <Search className="text-muted-foreground size-4 shrink-0" />
                  </Link>
                ))}
              </div>
            )}
          </div>

          <aside>
            <h2 className="font-medium">Workspace overview</h2>
            <div className="mt-4 grid grid-cols-2 gap-3 lg:grid-cols-1">
              <OverviewCard
                icon={UsersRound}
                label="Candidates"
                value={stats.candidates}
                href="/candidates"
              />
              <OverviewCard
                icon={CheckSquare}
                label="Due today"
                value={stats.tasks_due_today}
                href="/tasks"
              />
              <OverviewCard
                icon={CalendarDays}
                label="Open jobs"
                value={stats.open_jobs}
                href="/jobs"
              />
              <OverviewCard
                icon={Search}
                label="Presented"
                value={stats.presented}
                href="/pipeline"
              />
            </div>
          </aside>
        </section>
      </main>
    </AppLayout>
  )
}

function AssistantAction({
  icon: Icon,
  title,
  onClick,
}: {
  icon: typeof BarChart3
  title: string
  onClick: () => void
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="hover:bg-muted/50 flex items-center gap-3 rounded-xl border px-4 py-3 text-left text-sm transition-colors"
    >
      <Icon className="text-muted-foreground size-5" />
      <span className="font-medium">{title}</span>
    </button>
  )
}

function OverviewCard({
  icon: Icon,
  label,
  value,
  href,
}: {
  icon: typeof UsersRound
  label: string
  value: number
  href: string
}) {
  return (
    <Link
      href={href}
      className="hover:bg-muted/50 flex items-center justify-between rounded-xl border p-4"
    >
      <span className="text-muted-foreground flex items-center gap-2 text-sm">
        <Icon className="size-4" />
        {label}
      </span>
      <span className="text-lg font-semibold">{value}</span>
    </Link>
  )
}
