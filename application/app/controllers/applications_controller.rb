# frozen_string_literal: true

class ApplicationsController < InertiaController
  before_action :require_current_organization

  def index
    render inertia: "applications/index", props: ApplicationsWorkflowQuery.call(
      workspace_id: Current.organization.typed_id,
      user_id: Current.user.typed_id,
      view: params[:view]
    )
  end

  def update
    candidate = TalentProfile::Api.fetch_candidate_for_user(user_id: Current.user.typed_id)
    application = PersonalCrm::Api.fetch_application(
      workspace_id: Current.organization.typed_id,
      application_id: params[:id]
    )
    raise PersonalCrm::Api::NotFound, "application not found" unless application.fetch(:candidate_id) == candidate.fetch(:id)

    attributes = {
      workspace_id: Current.organization.typed_id,
      application_id: application.fetch(:id),
      command: command_provenance
    }

    case params.require(:kind)
    when "stage"
      PersonalCrm::Api.advance_application(**attributes, stage: params.require(:stage))
    when "next_action"
      PersonalCrm::Api.set_next_action(
        **attributes,
        next_action: params[:next_action],
        next_action_at: params[:next_action_at]
      )
    else
      raise PersonalCrm::Api::InvalidInput, "unknown application action"
    end

    redirect_to applications_path(view: return_view), status: :see_other
  rescue TalentProfile::Api::NotFound, PersonalCrm::Api::NotFound
    head :not_found
  rescue PersonalCrm::Api::InvalidInput, PersonalCrm::Api::ContractViolation
    head :unprocessable_entity
  end

  private

  def command_provenance
    {
      idempotency_key: params.require(:idempotency_key).to_s,
      principal: Current.user.typed_id,
      credential: Current.session.typed_id,
      actor: Current.user.typed_id,
      executor: "rails",
      interface: "web",
      client: "lmx-web",
      correlation_id: request.request_id
    }
  end

  def return_view
    value = params[:return_view].to_s
    %w[kanban list table].include?(value) ? value : "kanban"
  end
end
