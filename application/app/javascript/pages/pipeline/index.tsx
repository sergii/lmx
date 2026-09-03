import {
  DndContext,
  PointerSensor,
  closestCorners,
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
import { Columns3, List, Search, Table2 } from "lucide-react"
import { useState } from "react"

import Heading from "@/components/heading"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import AppLayout from "@/layouts/app-layout"
import { cn } from "@/lib/utils"

interface PipelineApplication {
  id: string
  stage: string
  candidate: {
    id: string
    first_name: string
    last_name: string
    email: string | null
    skills: string[]
  }
  job: string
  project: string
  client: string
}

type PipelineView = "kanban" | "list" | "table"

function CandidateCard({
  application,
  stages,
  moving,
  onMove,
}: {
  application: PipelineApplication
  stages: string[]
  moving: boolean
  onMove: (stage: string) => void
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
      className={`bg-background rounded-lg border p-3 shadow-sm ${isDragging ? "opacity-40" : ""}`}
    >
      <button
        type="button"
        {...attributes}
        {...listeners}
        aria-label={`Drag ${application.candidate.first_name} ${application.candidate.last_name}`}
        className="mb-2 w-full cursor-grab text-left active:cursor-grabbing"
      >
        <span className="font-medium hover:underline">
          {application.candidate.first_name} {application.candidate.last_name}
        </span>
      </button>
      <Link
        href={`/candidates/${application.candidate.id}`}
        className="text-muted-foreground text-xs hover:underline"
      >
        Open profile
      </Link>
      <Link
        href={`/candidates/${application.candidate.id}?application_id=${application.id}&schedule_meeting=1`}
        className="text-muted-foreground ml-3 text-xs hover:underline"
      >
        Schedule meeting
      </Link>
      <p className="text-muted-foreground mt-2 text-xs">{application.job}</p>
      <p className="text-muted-foreground text-xs">
        {application.project} / {application.client}
      </p>
      {application.candidate.skills.length > 0 && (
        <p className="mt-2 text-xs">
          {application.candidate.skills.slice(0, 3).join(" · ")}
        </p>
      )}
      <label className="sr-only" htmlFor={`stage-${application.id}`}>
        Move {application.candidate.first_name}{" "}
        {application.candidate.last_name}
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
            {stage.replaceAll("_", " ")}
          </option>
        ))}
      </select>
    </article>
  )
}

function PipelineColumn({
  stage,
  stages,
  applications,
  moving,
  onMove,
}: {
  stage: string
  stages: string[]
  applications: PipelineApplication[]
  moving: string | null
  onMove: (applicationId: string, nextStage: string) => void
}) {
  const { setNodeRef } = useSortable({ id: stage, data: { type: "column" } })
  return (
    <section
      ref={setNodeRef}
      className="bg-muted/30 flex min-h-0 flex-col rounded-xl border"
    >
      <div className="flex items-center justify-between border-b px-4 py-3">
        <h2 className="text-sm font-semibold capitalize">
          {stage.replaceAll("_", " ")}
        </h2>
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
            <CandidateCard
              key={application.id}
              application={application}
              stages={stages}
              moving={moving === application.id}
              onMove={(nextStage) => onMove(application.id, nextStage)}
            />
          ))}
          {applications.length === 0 && (
            <p className="text-muted-foreground rounded-md border border-dashed p-3 text-center text-xs">
              Drop candidates here
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
  view: PipelineView
  onChange: (view: PipelineView) => void
}) {
  const items: { view: PipelineView; label: string; icon: typeof Columns3 }[] =
    [
      { view: "kanban", label: "Kanban", icon: Columns3 },
      { view: "list", label: "List", icon: List },
      { view: "table", label: "Table", icon: Table2 },
    ]

  return (
    <div
      className="bg-muted inline-flex rounded-lg p-1"
      aria-label="Pipeline view"
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

function PipelineList({
  applications,
  stages,
  moving,
  onMove,
}: {
  applications: PipelineApplication[]
  stages: string[]
  moving: string | null
  onMove: (applicationId: string, nextStage: string) => void
}) {
  return (
    <div className="space-y-2">
      {applications.map((application) => (
        <article
          key={application.id}
          className="bg-card flex flex-col gap-3 rounded-xl border p-4 sm:flex-row sm:items-center"
        >
          <div className="min-w-0 flex-1">
            <Link
              href={`/candidates/${application.candidate.id}`}
              className="font-medium hover:underline"
            >
              {application.candidate.first_name}{" "}
              {application.candidate.last_name}
            </Link>
            <p className="text-muted-foreground text-sm">
              {application.job} · {application.project} / {application.client}
            </p>
            {application.candidate.skills.length > 0 && (
              <p className="text-muted-foreground mt-1 text-xs">
                {application.candidate.skills.join(" · ")}
              </p>
            )}
          </div>
          <select
            aria-label={`Move ${application.candidate.first_name} ${application.candidate.last_name}`}
            value={application.stage}
            disabled={moving === application.id}
            onChange={(event) => onMove(application.id, event.target.value)}
            className="border-input h-9 rounded-md border bg-transparent px-3 text-sm"
          >
            {stages.map((stage) => (
              <option key={stage} value={stage}>
                {stage.replaceAll("_", " ")}
              </option>
            ))}
          </select>
        </article>
      ))}
    </div>
  )
}

function PipelineTable({
  applications,
  stages,
  moving,
  onMove,
}: {
  applications: PipelineApplication[]
  stages: string[]
  moving: string | null
  onMove: (applicationId: string, nextStage: string) => void
}) {
  return (
    <div className="overflow-hidden rounded-xl border">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[48rem] text-left text-sm">
          <thead className="bg-muted/40 text-muted-foreground border-b">
            <tr>
              <th className="px-4 py-3 font-medium">Candidate</th>
              <th className="px-4 py-3 font-medium">Role</th>
              <th className="px-4 py-3 font-medium">Project</th>
              <th className="px-4 py-3 font-medium">Client</th>
              <th className="px-4 py-3 font-medium">Stage</th>
            </tr>
          </thead>
          <tbody>
            {applications.map((application) => (
              <tr key={application.id} className="border-b last:border-0">
                <td className="px-4 py-3">
                  <Link
                    href={`/candidates/${application.candidate.id}`}
                    className="font-medium hover:underline"
                  >
                    {application.candidate.first_name}{" "}
                    {application.candidate.last_name}
                  </Link>
                  <p className="text-muted-foreground text-xs">
                    {application.candidate.email ?? "No email"}
                  </p>
                </td>
                <td className="px-4 py-3">{application.job}</td>
                <td className="px-4 py-3">{application.project}</td>
                <td className="px-4 py-3">{application.client}</td>
                <td className="px-4 py-3">
                  <select
                    aria-label={`Move ${application.candidate.first_name} ${application.candidate.last_name}`}
                    value={application.stage}
                    disabled={moving === application.id}
                    onChange={(event) =>
                      onMove(application.id, event.target.value)
                    }
                    className="border-input h-8 rounded-md border bg-transparent px-2 text-xs"
                  >
                    {stages.map((stage) => (
                      <option key={stage} value={stage}>
                        {stage.replaceAll("_", " ")}
                      </option>
                    ))}
                  </select>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

export default function Pipeline({
  stages,
  applications,
}: {
  stages: string[]
  applications: PipelineApplication[]
}) {
  const [cards, setCards] = useState(applications)
  const [moving, setMoving] = useState<string | null>(null)
  const [view, setView] = useState<PipelineView>("kanban")
  const [query, setQuery] = useState("")
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } }),
  )
  const filteredCards = cards.filter((application) =>
    `${application.candidate.first_name} ${application.candidate.last_name} ${application.job} ${application.project} ${application.client} ${application.candidate.skills.join(" ")}`
      .toLocaleLowerCase()
      .includes(query.toLocaleLowerCase()),
  )

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
      { stage, return_to: "pipeline" },
      {
        preserveScroll: true,
        onError: () => setCards(originalCards),
        onFinish: () => setMoving(null),
      },
    )
  }

  function handleDragEnd(event: DragEndEvent) {
    const applicationId = String(event.active.id)
    const overId = event.over ? String(event.over.id) : null
    if (!overId) return
    const target = cards.find((card) => card.id === overId)
    move(applicationId, target?.stage ?? overId)
  }

  return (
    <AppLayout breadcrumbs={[{ title: "Pipeline", href: "/pipeline" }]}>
      <Head title="Pipeline" />
      <div className="flex min-h-0 flex-1 flex-col p-6">
        <div className="mb-6 flex flex-col gap-4 xl:flex-row xl:items-end xl:justify-between">
          <Heading
            title="Pipeline"
            description="Manage every active candidate application."
          />
          <Button asChild>
            <Link href="/candidates/new">Source candidate</Link>
          </Button>
        </div>
        <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <ViewSwitcher view={view} onChange={setView} />
          <div className="relative w-full sm:w-80">
            <Search className="text-muted-foreground pointer-events-none absolute top-2.5 left-3 size-4" />
            <Input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search candidates, roles, projects…"
              className="pl-9"
            />
          </div>
        </div>
        {view === "kanban" && (
          <DndContext
            sensors={sensors}
            collisionDetection={closestCorners}
            onDragEnd={handleDragEnd}
          >
            <div className="grid min-h-0 flex-1 auto-cols-[18rem] grid-flow-col gap-4 overflow-x-auto pb-4">
              {stages.map((stage) => (
                <PipelineColumn
                  key={stage}
                  stage={stage}
                  stages={stages}
                  applications={filteredCards.filter(
                    (card) => card.stage === stage,
                  )}
                  moving={moving}
                  onMove={move}
                />
              ))}
            </div>
          </DndContext>
        )}
        {view === "list" && (
          <PipelineList
            applications={filteredCards}
            stages={stages}
            moving={moving}
            onMove={move}
          />
        )}
        {view === "table" && (
          <PipelineTable
            applications={filteredCards}
            stages={stages}
            moving={moving}
            onMove={move}
          />
        )}
      </div>
    </AppLayout>
  )
}
