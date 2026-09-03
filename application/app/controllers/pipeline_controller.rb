# frozen_string_literal: true

class PipelineController < InertiaController
  before_action :require_current_organization

  def index
    applications = Application.includes(:candidate, job: { project: :client_company }).order(created_at: :desc)

    render inertia: "pipeline/index", props: {
      stages: Application::STAGES,
      applications: applications.map do |application|
        {
          id: application.typed_id,
          stage: application.stage,
          candidate: application.candidate.slice(:first_name, :last_name, :email, :skills).merge(id: application.candidate.typed_id),
          job: application.job.title,
          project: application.job.project.name,
          client: application.job.project.client_company.name
        }
      end
    }
  end
end
