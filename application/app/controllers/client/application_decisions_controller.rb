# frozen_string_literal: true

class Client::ApplicationDecisionsController < Client::PortalController
  def create
    return head :not_found unless Current.membership.role == "client_hiring_manager"

    application = authorized_scope(Application.includes(:client_decision, :sourced_by, job: :project), with: Client::ApplicationPolicy).find_by(client_portal_id: params[:application_id])
    return head :not_found unless application

    authorize! application, to: :decide?, with: Client::ApplicationPolicy

    decision = ClientDecision.new(
      application:,
      decided_by: Current.user,
      decision: params.require(:decision),
      note: params[:note].presence,
      decided_at: Time.current
    )
    recipient = application.client_decision_recipient
    return redirect_to(client_application_path(application.client_portal_id), alert: "No recruiter is assigned to receive this decision") unless recipient

    Application.transaction do
      decision.save!
      application.move_to!(stage: decision.target_stage, moved_by: Current.user)
      Task.create!(
        created_by: Current.user,
        assigned_to: recipient,
        title: "Client #{application.client_company.name} #{decision.decision} #{application.candidate.first_name} #{application.candidate.last_name} for #{application.job.title}",
        due_on: Date.current
      )
    end

    redirect_to client_application_path(application.client_portal_id), notice: "Candidate #{decision.decision}"
  rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid => error
    redirect_to client_application_path(params[:application_id]), inertia: { errors: { decision: error.message } }
  end
end
