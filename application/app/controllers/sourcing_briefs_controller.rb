# frozen_string_literal: true

class SourcingBriefsController < InertiaController
  before_action :require_current_organization
  before_action :set_job

  def create
    brief = @job.build_sourcing_brief(brief_params)
    apply_approval!(brief)
    authorize! brief

    if brief.save
      redirect_to job_path(@job), notice: "Sourcing brief saved"
    else
      redirect_to job_path(@job), inertia: { errors: brief.errors }
    end
  end

  def update
    brief = @job.sourcing_brief
    authorize! brief
    brief.assign_attributes(brief_params)
    apply_approval!(brief)

    if brief.save
      redirect_to job_path(@job), notice: "Sourcing brief updated"
    else
      redirect_to job_path(@job), inertia: { errors: brief.errors }
    end
  end

  private

  def set_job
    @job = Job.find_by_typed_id!(params[:job_id])
    authorize! @job, to: :show?
  end

  def brief_params
    permitted = params.permit(:status, :summary, :language_requirement, :interview_focus,
                              must_haves: [], nice_to_haves: [], exclusions: [], search_queries: [], location_preferences: [])
    %w[must_haves nice_to_haves exclusions search_queries location_preferences].each do |field|
      permitted[field] = Array(permitted[field]).flat_map { |value| value.to_s.split(",") }.map(&:strip).reject(&:blank?)
    end
    permitted
  end

  def apply_approval!(brief)
    if brief.status == "approved"
      brief.approved_by = Current.user
      brief.approved_at ||= Time.current
    else
      brief.approved_by = nil
      brief.approved_at = nil
    end
  end
end
