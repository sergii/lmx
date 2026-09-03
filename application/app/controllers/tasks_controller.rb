# frozen_string_literal: true

class TasksController < InertiaController
  before_action :require_current_organization

  def index
    render inertia: "tasks/index", props: { tasks: Task.includes(:assigned_to).order(completed_at: :asc, due_on: :asc, created_at: :desc).map { |task| task_props(task) } }
  end

  def create
    task = Task.new(task_params.merge(created_by: Current.user, assigned_to: Current.user))

    if task.save
      redirect_to tasks_path, notice: "Task created"
    else
      redirect_to tasks_path, inertia: { errors: task.errors }
    end
  end

  def update
    task = Task.find_by_typed_id!(params[:id])
    task.update!(completed_at: ActiveModel::Type::Boolean.new.cast(params[:completed]) ? Time.current : nil)
    redirect_to tasks_path, notice: task.completed? ? "Task completed" : "Task reopened"
  end

  private

  def task_params
    params.permit(:title, :due_on)
  end

  def task_props(task)
    {
      id: task.typed_id,
      title: task.title,
      due_on: task.due_on&.iso8601,
      completed: task.completed?,
      assigned_to: task.assigned_to.name
    }
  end
end
