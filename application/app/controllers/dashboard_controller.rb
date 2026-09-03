# frozen_string_literal: true

class DashboardController < InertiaController
  def index
    render inertia: "dashboard/index", props: {
      greeting_name: Current.user&.name.to_s.split.first.presence || "there",
      stats: {
        candidates: Candidate.count,
        open_jobs: Job.where(status: "open").count,
        presented: Application.where(stage: "presented").count,
        clients: ClientCompany.count,
        tasks_due_today: Task.where(completed_at: nil, due_on: Date.current).count
      },
      recent_candidates: Candidate.order(created_at: :desc).limit(5).map do |candidate|
        {
          id: candidate.typed_id,
          name: "#{candidate.first_name} #{candidate.last_name}",
          skills: candidate.skills,
          created_at: candidate.created_at.iso8601
        }
      end,
      tasks_due_today: Task.where(completed_at: nil, due_on: Date.current).order(:created_at).limit(3).map { |task| { id: task.typed_id, title: task.title } },
      projects: Project.includes(:client_company).order(:name).map do |project|
        {
          id: project.typed_id,
          name: project.name,
          client_name: project.client_company.name
        }
      end
    }
  end
end
