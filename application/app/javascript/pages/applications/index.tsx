import {
  DndContext,
  PointerSensor,
  closestCorners,
  useDroppable,
  useSensor,
  useSensors,
} from "@dnd-kit/core"
import type { DragEndEvent } from "@dnd-kit/core"
import {
  SortableContext,
  useSortable,
  verticalListSortingStrategy,
} from "@dnd-kit/sortable"
import { CSS } from "@dnd-kit/utilities"
import { Head, Link, router } from "@inertiajs/react"
import { format, formatDistanceToNowStrict } from "date-fns"
import {
  ArrowUpRight,
  CalendarClock,
  Columns3,
  List,
  Search,
  Table2,
} from "lucide-react"
import { useState } from "react"

import Heading from "@/components/heading"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import AppLayout from "@/layouts/app-layout"
import { cn } from "@/lib/utils"

interface OpeningSummary {
  id: string
  title: string
  lifecycle_state: string
  company: {
    id: string
    name: string
  } | null
}

interface ApplicationAttempt {
  id: string
  stage: string
  started_at: string | null
  applied_at: string | null
  channel: string | null
  next_action: string | null
  next_action_at: string | null
  job_opening_id: string
  via_posting_id: string | null
  opening: OpeningSummary | null
}

interface CandidateSummary {
  id: string
  name: string
}

type WorkflowView = "kanban" | "list" | "table"

interface Props {
  stages: string[]
  initial_view: WorkflowView
  candidate: CandidateSummary | null
  applications: ApplicationAttempt[]
}

function humanize(value: string) {
  return value.replaceAll("_", " ")
}

function dateTime(value: string | null) {
  return value ? format(new Date(value), "MMM d, yyyy · HH:mm") : "Unknown"
}

function relativeTime(value: string | null) {
  return value
    ? formatDistanceToNowStrict(new Date(value), { addSuffix: true })
    : "Unknown"
}

function localDateTimeInput(value: string | null) {
  return value ? format(new Date(value), "yyyy-MM-dd'T'HH:mm") : ""
}

function lifecycleVariant(state: string) {
  if (state === "closed") return "secondary" as const
  if (state === "missing" || state === "probably_closed")
    return "outline" as const
  return "default" as const
}

function ApplicationTitle({ application }: { application: ApplicationAttempt }) {
  return (
    <div className="min-w-0">
      <Link
        href={`/openings/${application.job_opening_id}`}
        className="font-medium hover:underline"
      >
        {application.opening?.title ?? "Unknown opening"}
      </Link>
      <p className="text-muted-foreground mt-0.5 text-xs">
        {application.opening?.company?.name ?? "Unknown company"}
      </p>
    </div>
  )
}

function NextActionEditor({
  application,
  saving,
  onSave,
}: {
  application: ApplicationAttempt
  saving: boolean
  onSave: (nextAction: string, nextActionAt: string | null) => void
}) {
  const [nextAction, setNextAction] = useState(application.next_action ?? "")
  const [nextActionAt, setNextActionAt] = useState(
    localDateTimeInput(application.next_action_at),
  )

  return (
    <div className="mt-3 space-y-2 border-t pt-3">
      <Input
        aria-label="Next action"
        value={nextAction}
        onChange={(event) => setNextAction(event.target.value)}
        placeholder="Next action"
        className="h-8 text-xs"
      />
      <div className="flex gap-2">
        <Input
          aria-label="Next action time"
          type="datetime-local"
          value={nextActionAt}
          onChange={(event) => setNextActionAt(event.target.value)}
          className="h-8 min-w-0 text-xs"
        />
        <Button
          type="button"
          size="sm"
          variant="outline"
          disabled={saving}
          onClick={() =>
            onSave(
              nextAction,
              nextActionAt ? new Date(nextActionAt).toISOString() : null,
            )
          }
        >
          {saving ? "Saving..." : "Save"}
        </Button>
      </div>
    </div>
  )
}

function ApplicationCard({
  application,
  stages,
  moving,
  savingAction,
  onMove,
  onSaveNextAction,
}: {
  application: ApplicationAttempt
  stages: string[]
  moving: boolean
  savingAction: boolean
  onMove: (stage: string) => void
  onSaveNextAction: (nextAction: string, nextActionAt: string | null) => void
}) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: application.id })
  const style = { transform: CSS.Transform.toString(transform), transition }

  return (
    <article
      ref={setNodeRef}
      style={style}
      className={cn(
        "bg-background rounded-lg border p-3 shadow-sm",
        isDragging && "opacity-40",
      )}
    >
      <button
        type="button"
        {...attributes}
        {...listeners}
        aria-label={`Drag ${application.opening?.title ?? "application"}`}
        className="mb-2 w-full cursor-grab text-left active:cursor-grabbing"
      >
        <ApplicationTitle application={application} />
      </button>

      <div className="text-muted-foreground flex flex-wrap gap-x-2 gap-y-1 text-xs">
        <span>Started {relativeTime(application.started_at)}</span>
        {application.channel && <span>· {application.channel}</span>}
      </div>

      {application.next_action && (
        <div className="mt-3 rounded-md border px-3 py-2 text-xs">
          <div className="flex items-center gap-1.5 font-medium">
            <CalendarClock className="size-3.5" />
            {application.next_action}
          </div>
          {application.next_action_at && (
            <p className="text-muted-foreground mt-1">
              {dateTime(application.next_action_at)}
            </p>
          )}
        </div>
      )}

      <label className="sr-only" htmlFor={`stage-${application.id}`}>
        Application stage
      </label>
      <select
        id={`stage-${application.id}`}
        value={application.stage}
        disabled={moving}
        onChange={(event) => onMove(event.target.value)}
        className="border-input mt-3 h-8 w-full rounded-md border bg-transparent px-2 text-xs"
      >
        {stages.map((stage) => (
          <option key={stage} value={stage}>
            {humanize(stage)}
          </option>
        ))}
      </select>

      <NextActionEditor
        application={application}
        saving={savingAction}
        onSave={onSaveNextAction}
      />
    </article>
  )
}

function PipelineColumn({
  stage,
  stages,
  applications,
  moving,
  savingAction,
  onMove,
  onSaveNextAction,
}: {
  stage: string
  stages: string[]
  applications: ApplicationAttempt[]
  moving: string | null
  savingAction: string | null
  onMove: (applicationId: string, stage: string) => void
  onSaveNextAction: (
    applicationId: string,
    nextAction: string,
    nextActionAt: string | null,
  ) => void
}) {
  const { setNodeRef, isOver } = useDroppable({ id: `stage:${stage}` })

  return (
    <section
      ref={setNodeRef}
      className={cn(
        "bg-muted/30 flex min-h-0 flex-col rounded-xl border",
        isOver && "ring-ring ring-2",
      )}
    >
      <div className="flex items-center justify-between border-b px-4 py-3">
        <h2 className="text-sm font-semibold capitalize">{humanize(stage)}</h2>
        <span className="text-muted-foreground text-xs">
          {applications.length}
        </span>
      </div>
      <SortableContext
        items={applications.map((application) => application.id)}
        strategy={verticalListSortingStrategy}
      >
        <div className="min-h-28 space-y-3 overflow-y-auto p-3">
          {applications.map((application) => (
            <ApplicationCard
              key={application.id}
              application={application}
              stages={stages}
              moving={moving === application.id}
              savingAction={savingAction === application.id}
              onMove={(nextStage) => onMove(application.id, nextStage)}
              onSaveNextAction={(nextAction, nextActionAt) =>
                onSaveNextAction(application.id, nextAction, nextActionAt)
              }
            />
          ))}
          {applications.length === 0 && (
            <p className="text-muted-foreground rounded-md border border-dashed p-3 text-center text-xs">
              Drop applications here
            </p>
          )}
        </div>
      </SortableContext>
    </section>
  )
}

function ViewSwitcher({
  view,
  onChange,
}: {
  view: WorkflowView
  onChange: (view: WorkflowView) => void
}) {
  const items: {
    view: WorkflowView
    label: string
    icon: typeof Columns3
  }[] = [
    { view: "kanban", label: "Kanban", icon: Columns3 },
    { view: "list", label: "List", icon: List },
    { view: "table", label: "Table", icon: Table2 },
  ]

  return (
    <div
      className="bg-muted inline-flex rounded-lg p-1"
      aria-label="Applications view"
    >
      {items.map((item) => {
        const Icon = item.icon
        return (
          <button
            key={item.view}
            type="button"
            onClick={() => onChange(item.view)}
            className={cn(
              "text-muted-foreground inline-flex h-8 items-center gap-2 rounded-md px-3 text-sm font-medium",
              view === item.view && "bg-background text-foreground shadow-sm",
            )}
          >
            <Icon className="size-4" />
            {item.label}
          </button>
        )
      })}
    </div>
  )
}

function StageSelect({
  application,
  stages,
  moving,
  onMove,
}: {
  application: ApplicationAttempt
  stages: string[]
  moving: boolean
  onMove: (stage: string) => void
}) {
  return (
    <select
      aria-label={`Stage for ${application.opening?.title ?? "application"}`}
      value={application.stage}
      disabled={moving}
      onChange={(event) => onMove(event.target.value)}
      className="border-input h-9 rounded-md border bg-transparent px-3 text-sm"
    >
      {stages.map((stage) => (
        <option key={stage} value={stage}>
          {humanize(stage)}
        </option>
      ))}
    </select>
  )
}

function ApplicationList({
  applications,
  stages,
  moving,
  savingAction,
  onMove,
  onSaveNextAction,
}: {
  applications: ApplicationAttempt[]
  stages: string[]
  moving: string | null
  savingAction: string | null
  onMove: (applicationId: string, stage: string) => void
  onSaveNextAction: (
    applicationId: string,
    nextAction: string,
    nextActionAt: string | null,
  ) => void
}) {
  return (
    <div className="space-y-3">
      {applications.map((application) => (
        <article key={application.id} className="bg-card rounded-xl border p-4">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-start">
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2">
                <ApplicationTitle application={application} />
                {application.opening && (
                  <Badge
                    variant={lifecycleVariant(application.opening.lifecycle_state)}
                  >
                    {humanize(application.opening.lifecycle_state)}
                  </Badge>
                )}
              </div>
              <p className="text-muted-foreground mt-2 text-xs">
                Started {dateTime(application.started_at)}
                {application.applied_at &&
                  ` · Applied ${dateTime(application.applied_at)}`}
              </p>
            </div>
            <StageSelect
              application={application}
              stages={stages}
              moving={moving === application.id}
              onMove={(stage) => onMove(application.id, stage)}
            />
          </div>
          <div className="mt-3 max-w-2xl">
            <NextActionEditor
              application={application}
              saving={savingAction === application.id}
              onSave={(nextAction, nextActionAt) =>
                onSaveNextAction(application.id, nextAction, nextActionAt)
              }
            />
          </div>
        </article>
      ))}
    </div>
  )
}

function ApplicationTable({
  applications,
  stages,
  moving,
  onMove,
}: {
  applications: ApplicationAttempt[]
  stages: string[]
  moving: string | null
  onMove: (applicationId: string, stage: string) => void
}) {
  return (
    <div className="overflow-hidden rounded-xl border">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[64rem] text-left text-sm">
          <thead className="bg-muted/40 text-muted-foreground border-b">
            <tr>
              <th className="px-4 py-3 font-medium">Opening</th>
              <th className="px-4 py-3 font-medium">Stage</th>
              <th className="px-4 py-3 font-medium">Started</th>
              <th className="px-4 py-3 font-medium">Applied</th>
              <th className="px-4 py-3 font-medium">Next action</th>
              <th className="px-4 py-3 font-medium">Due</th>
            </tr>
          </thead>
          <tbody>
            {applications.map((application) => (
              <tr key={application.id} className="border-b last:border-0">
                <td className="px-4 py-3">
                  <ApplicationTitle application={application} />
                </td>
                <td className="px-4 py-3">
                  <StageSelect
                    application={application}
                    stages={stages}
                    moving={moving === application.id}
                    onMove={(stage) => onMove(application.id, stage)}
                  />
                </td>
                <td className="px-4 py-3">{dateTime(application.started_at)}</td>
                <td className="px-4 py-3">{dateTime(application.applied_at)}</td>
                <td className="max-w-72 px-4 py-3">
                  {application.next_action ?? "-"}
                </td>
                <td className="px-4 py-3">
                  {application.next_action_at
                    ? dateTime(application.next_action_at)
                    : "-"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

export default function ApplicationsIndex({
  stages,
  initial_view,
  candidate,
  applications,
}: Props) {
  const [cards, setCards] = useState(applications)
  const [moving, setMoving] = useState<string | null>(null)
  const [savingAction, setSavingAction] = useState<string | null>(null)
  const [view, setView] = useState<WorkflowView>(initial_view)
  const [query, setQuery] = useState("")
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } }),
  )

  const filteredCards = cards.filter((application) => {
    const searchable = [
      application.opening?.title,
      application.opening?.company?.name,
      application.stage,
      application.next_action,
      application.channel,
    ]
      .filter(Boolean)
      .join(" ")
      .toLocaleLowerCase()
    return searchable.includes(query.toLocaleLowerCase())
  })

  function move(applicationId: string, stage: string) {
    const originalCards = cards
    const application = cards.find((card) => card.id === applicationId)
    if (!application || application.stage === stage) return

    setMoving(applicationId)
    setCards((current) =>
      current.map((card) =>
        card.id === applicationId ? { ...card, stage } : card,
      ),
    )
    router.patch(
      `/applications/${applicationId}`,
      {
        kind: "stage",
        stage,
        idempotency_key: crypto.randomUUID(),
        return_view: view,
      },
      {
        preserveScroll: true,
        preserveState: true,
        onError: () => setCards(originalCards),
        onFinish: () => setMoving(null),
      },
    )
  }

  function saveNextAction(
    applicationId: string,
    nextAction: string,
    nextActionAt: string | null,
  ) {
    const originalCards = cards
    setSavingAction(applicationId)
    setCards((current) =>
      current.map((card) =>
        card.id === applicationId
          ? {
              ...card,
              next_action: nextAction.trim() || null,
              next_action_at: nextActionAt,
            }
          : card,
      ),
    )
    router.patch(
      `/applications/${applicationId}`,
      {
        kind: "next_action",
        next_action: nextAction,
        next_action_at: nextActionAt,
        idempotency_key: crypto.randomUUID(),
        return_view: view,
      },
      {
        preserveScroll: true,
        preserveState: true,
        onError: () => setCards(originalCards),
        onFinish: () => setSavingAction(null),
      },
    )
  }

  function handleDragEnd(event: DragEndEvent) {
    const applicationId = String(event.active.id)
    const overId = event.over ? String(event.over.id) : null
    if (!overId) return

    if (overId.startsWith("stage:")) {
      move(applicationId, overId.slice("stage:".length))
      return
    }

    const target = cards.find((card) => card.id === overId)
    if (target) move(applicationId, target.stage)
  }

  return (
    <AppLayout breadcrumbs={[{ title: "Applications", href: "/applications" }]}>
      <Head title="Applications" />
      <div className="flex min-h-0 flex-1 flex-col p-6">
        <div className="mb-6 flex flex-col gap-4 xl:flex-row xl:items-end xl:justify-between">
          <Heading
            title="Applications"
            description={
              candidate
                ? `Track every application attempt for ${candidate.name}.`
                : "Link a Candidate profile to start tracking applications."
            }
          />
          <Button asChild variant="outline">
            <Link href="/openings">
              Find openings
              <ArrowUpRight className="size-4" />
            </Link>
          </Button>
        </div>

        {!candidate ? (
          <div className="text-muted-foreground rounded-xl border border-dashed p-8 text-sm">
            No canonical Candidate is linked to this user yet. Applications stay
            empty until a Candidate profile is linked.
          </div>
        ) : (
          <>
            <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <ViewSwitcher view={view} onChange={setView} />
              <div className="relative w-full sm:w-80">
                <Search className="text-muted-foreground pointer-events-none absolute top-2.5 left-3 size-4" />
                <Input
                  value={query}
                  onChange={(event) => setQuery(event.target.value)}
                  placeholder="Search openings, companies, actions…"
                  className="pl-9"
                />
              </div>
            </div>

            {filteredCards.length === 0 && query && (
              <div className="text-muted-foreground mb-4 rounded-xl border border-dashed p-6 text-sm">
                No applications match this search.
              </div>
            )}

            {cards.length === 0 && !query && (
              <div className="text-muted-foreground rounded-xl border border-dashed p-8 text-sm">
                No application attempts yet. Open an opportunity and choose Apply
                to start one.
              </div>
            )}

            {cards.length > 0 && view === "kanban" && (
              <DndContext
                sensors={sensors}
                collisionDetection={closestCorners}
                onDragEnd={handleDragEnd}
              >
                <div className="grid min-h-0 flex-1 auto-cols-[20rem] grid-flow-col gap-4 overflow-x-auto pb-4">
                  {stages.map((stage) => (
                    <PipelineColumn
                      key={stage}
                      stage={stage}
                      stages={stages}
                      applications={filteredCards.filter(
                        (application) => application.stage === stage,
                      )}
                      moving={moving}
                      savingAction={savingAction}
                      onMove={move}
                      onSaveNextAction={saveNextAction}
                    />
                  ))}
                </div>
              </DndContext>
            )}

            {cards.length > 0 && view === "list" && (
              <ApplicationList
                applications={filteredCards}
                stages={stages}
                moving={moving}
                savingAction={savingAction}
                onMove={move}
                onSaveNextAction={saveNextAction}
              />
            )}

            {cards.length > 0 && view === "table" && (
              <ApplicationTable
                applications={filteredCards}
                stages={stages}
                moving={moving}
                onMove={move}
              />
            )}
          </>
        )}
      </div>
    </AppLayout>
  )
}
