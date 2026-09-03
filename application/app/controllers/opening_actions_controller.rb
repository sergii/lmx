# frozen_string_literal: true

class OpeningActionsController < InertiaController
  before_action :require_current_organization

  def create
    candidate = TalentProfile::Api.fetch_candidate_for_user(user_id: Current.user.typed_id)
    attributes = {
      workspace_id: Current.organization.typed_id,
      candidate_id: candidate.fetch(:id),
      job_opening_id: params[:id],
      command: command_provenance
    }

    case params.require(:kind)
    when "save"
      PersonalCrm::Api.save_opening(**attributes)
    when "ignore"
      PersonalCrm::Api.ignore_opening(**attributes)
    when "apply"
      PersonalCrm::Api.start_application(**attributes)
    else
      raise PersonalCrm::Api::InvalidInput, "unknown opening action"
    end

    redirect_to opening_path(params[:id]), status: :see_other
  rescue TalentProfile::Api::NotFound, MarketCatalog::Api::NotFound, PersonalCrm::Api::NotFound
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
end
