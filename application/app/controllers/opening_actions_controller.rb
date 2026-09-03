# frozen_string_literal: true

class OpeningActionsController < InertiaController
  before_action :require_current_organization

  def save
    mutate(:save_opportunity)
  end

  def ignore
    mutate(:ignore_opportunity)
  end

  def apply
    mutate(:apply_to_opportunity)
  end

  private

  def mutate(operation)
    candidate = TalentProfile::Api.fetch_candidate_for_user(user_id: Current.user.typed_id)

    PersonalCrm::Api.public_send(
      operation,
      workspace_id: Current.organization.typed_id,
      candidate_id: candidate.fetch(:id),
      job_opening_id: params[:id],
      command: command_provenance(operation)
    )

    redirect_to opening_path(params[:id]), status: :see_other
  rescue TalentProfile::Api::NotFound
    redirect_to opening_path(params[:id]),
      alert: "Complete your candidate profile before changing personal opportunity state.",
      status: :see_other
  rescue MarketCatalog::Api::NotFound, PersonalCrm::Api::NotFound
    head :not_found
  rescue PersonalCrm::Api::InvalidInput, PersonalCrm::Api::InvalidTransition => error
    redirect_to opening_path(params[:id]), alert: error.message, status: :see_other
  end

  def command_provenance(operation)
    request_id = request.request_id.presence || SecureRandom.uuid
    user_id = Current.user.typed_id

    {
      command_id: "web:opening:#{operation}:#{request_id}",
      idempotency_key: "web:opening:#{operation}:#{request_id}",
      principal: user_id,
      credential: Current.session.typed_id,
      actor: user_id,
      executor: "lmx_web",
      interface: "web",
      client: "lmx"
    }
  end
end
