# frozen_string_literal: true

class ProjectsController < InertiaController
  before_action :require_current_organization

  def index
    render inertia: "projects/index", props: {
      clients: ClientCompany.order(:name).map { |client| client.slice(:name).merge(id: client.typed_id) },
      projects: Project.includes(:client_company).order(:name).map { |project| { id: project.typed_id, name: project.name, client: project.client_company.name } }
    }
  end

  def create
    project = Project.new(params.permit(:name).merge(client_company_id: ClientCompany.typed_id_value(params[:client_company_id])))
    if project.save
      redirect_to jobs_path, notice: "Project created"
    else
      redirect_to projects_path, inertia: { errors: project.errors }
    end
  end
end
