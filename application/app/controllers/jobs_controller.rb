# frozen_string_literal: true

class JobsController < InertiaController
  before_action :require_current_organization

  def index
    authorize! Job

    render inertia: "jobs/index", props: {
      projects: Project.includes(:client_company).order(:name).map { |project| { id: project.typed_id, name: project.name, client: project.client_company.name } },
      jobs: Job.includes(project: :client_company).order(created_at: :desc).map { |job| job_props(job) }
    }
  end

  def create
    job = Job.new(params.permit(:title, :seniority, :technology_stack, :status).merge(project_id: Project.typed_id_value(params[:project_id])))
    authorize! job
    if job.save
      redirect_to jobs_path, notice: "Job created"
    else
      redirect_to jobs_path, inertia: { errors: job.errors }
    end
  end

  def show
    job = Job.includes(:sourcing_brief, :job_postings, project: :client_company).find_by_typed_id!(params[:id])
    authorize! job
    applications = job.applications.includes(:candidate).order(created_at: :desc)
    render inertia: "jobs/show", props: {
      job: job_props(job),
      sourcingBrief: sourcing_brief_props(job.sourcing_brief),
      postings: job.job_postings.order(created_at: :desc).map { |posting| posting_props(posting) },
      postingChannels: JobPosting::CHANNELS,
      postingStatuses: JobPosting::STATUSES,
      sourcingBriefStatuses: SourcingBrief::STATUSES,
      stages: Application::STAGES,
      applications: applications.map do |application|
        {
          id: application.typed_id,
          stage: application.stage,
          candidate: application.candidate.slice(:first_name, :last_name, :email, :skills).merge(id: application.candidate.typed_id)
        }
      end
    }
  end

  def update
    job = Job.find_by_typed_id!(params[:id])
    authorize! job

    if job.update(job_params)
      redirect_to job_path(job), notice: "Job brief updated"
    else
      redirect_to job_path(job), inertia: { errors: job.errors }
    end
  end

  private

  def job_props(job)
    job.slice(:title, :seniority, :technology_stack, :status, :description).merge(id: job.typed_id, project: job.project.name, client: job.project.client_company.name)
  end

  def job_params
    params.permit(:title, :seniority, :technology_stack, :status, :description)
  end

  def sourcing_brief_props(brief)
    return unless brief

    brief.slice(:status, :summary, :must_haves, :nice_to_haves, :exclusions, :search_queries, :location_preferences, :language_requirement, :interview_focus).merge(id: brief.typed_id, approved_at: brief.approved_at&.iso8601)
  end

  def posting_props(posting)
    posting.slice(:channel, :status, :title, :public_url, :content_snapshot).merge(id: posting.typed_id, published_at: posting.published_at&.iso8601, closed_at: posting.closed_at&.iso8601)
  end
end
