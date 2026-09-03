# frozen_string_literal: true

class ApplicationsController < InertiaController
  before_action :require_current_organization

  def update
    application = Application.find_by_typed_id!(params[:id])
    application.move_to!(stage: params.require(:stage), moved_by: Current.user)
    redirect_to destination_for(application), notice: "Candidate moved to #{application.stage.humanize}"
  rescue ArgumentError, ActiveRecord::RecordInvalid => error
    redirect_to destination_for(application), inertia: { errors: { stage: error.message } }
  end

  private

  def destination_for(application)
    params[:return_to] == "pipeline" ? pipeline_path : job_path(application.job_id)
  end
end
