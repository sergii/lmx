import { Form, Head, router } from "@inertiajs/react"
import { CalendarDays, CirclePlus, ListTodo } from "lucide-react"
import { useState } from "react"

import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import AppLayout from "@/layouts/app-layout"

type Task = {
  id: string
  title: string
  due_on: string | null
  completed: boolean
  assigned_to: string
}

export default function Tasks({ tasks }: { tasks: Task[] }) {
  const [open, setOpen] = useState(false)
  const openTasks = tasks.filter((task) => !task.completed)
  const completedTasks = tasks.filter((task) => task.completed)

  return (
    <AppLayout breadcrumbs={[{ title: "Tasks", href: "/tasks" }]}>
      <Head title="Tasks" />
      <main className="p-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold">Tasks</h1>
            <p className="text-muted-foreground mt-1 text-sm">
              Simple personal reminders for recruiter follow-ups and hiring
              work.
            </p>
          </div>
          <CreateTaskDialog open={open} onOpenChange={setOpen} />
        </div>
        {tasks.length === 0 ? (
          <EmptyTasks onCreate={() => setOpen(true)} />
        ) : (
          <div className="mt-8 max-w-5xl overflow-hidden rounded-xl border">
            <div className="bg-muted/30 text-muted-foreground grid grid-cols-[minmax(0,1fr)_130px_170px] gap-4 border-b px-4 py-3 text-xs font-medium">
              <span>Task</span>
              <span>Due date</span>
              <span>Assigned to</span>
            </div>
            <TaskRows tasks={openTasks} />
            <TaskRows tasks={completedTasks} completed />
          </div>
        )}
      </main>
    </AppLayout>
  )
}

function CreateTaskDialog({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogTrigger asChild>
        <Button>
          <CirclePlus /> New task
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Create task</DialogTitle>
          <DialogDescription>
            Add a reminder for yourself. You can complete or reopen it from the
            list.
          </DialogDescription>
        </DialogHeader>
        <Form
          action="/tasks"
          method="post"
          onSuccess={() => onOpenChange(false)}
        >
          {({ processing, errors }) => (
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="title">Task</FieldLabel>
                <Input
                  id="title"
                  name="title"
                  required
                  autoFocus
                  placeholder="Follow up with candidate"
                />
                <FieldError
                  errors={errors.title?.map((message) => ({ message }))}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="due_on">Due date</FieldLabel>
                <Input id="due_on" name="due_on" type="date" />
              </Field>
              <Button type="submit" disabled={processing}>
                Create task
              </Button>
            </FieldGroup>
          )}
        </Form>
      </DialogContent>
    </Dialog>
  )
}

function EmptyTasks({ onCreate }: { onCreate: () => void }) {
  return (
    <div className="mx-auto mt-20 max-w-sm text-center">
      <span className="bg-muted mx-auto flex size-16 items-center justify-center rounded-2xl">
        <ListTodo className="text-muted-foreground size-7" />
      </span>
      <h2 className="mt-5 text-xl font-semibold">No tasks yet</h2>
      <p className="text-muted-foreground mt-2 text-sm">
        Create your first reminder to keep candidate follow-ups moving.
      </p>
      <Button className="mt-5" onClick={onCreate}>
        <CirclePlus /> New task
      </Button>
    </div>
  )
}

function TaskRows({
  tasks,
  completed = false,
}: {
  tasks: Task[]
  completed?: boolean
}) {
  if (!tasks.length) return null
  return (
    <>
      {tasks.map((task) => (
        <div
          key={task.id}
          className="grid grid-cols-[minmax(0,1fr)_130px_170px] items-center gap-4 border-b px-4 py-3 text-sm last:border-b-0"
        >
          <span className="flex min-w-0 items-center gap-3">
            <Checkbox
              checked={task.completed}
              onCheckedChange={(checked) =>
                router.patch(`/tasks/${task.id}`, { completed: checked })
              }
            />
            <span
              className={
                completed
                  ? "text-muted-foreground line-through"
                  : "truncate font-medium"
              }
            >
              {task.title}
            </span>
          </span>
          <span className="text-muted-foreground flex items-center gap-1.5">
            {task.due_on ? (
              <>
                <CalendarDays className="size-3.5" />
                {new Intl.DateTimeFormat(undefined, {
                  month: "short",
                  day: "numeric",
                }).format(new Date(`${task.due_on}T00:00:00`))}
              </>
            ) : (
              "No due date"
            )}
          </span>
          <span className="text-muted-foreground">{task.assigned_to}</span>
        </div>
      ))}
    </>
  )
}
