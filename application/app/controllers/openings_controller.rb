# frozen_string_literal: true

class OpeningsController < InertiaController
  before_action :require_current_organization

  def index
    render inertia: "openings/index", props: OpeningsInboxQuery.call(
      workspace_id: Current.organization.typed_id,
      user_id: Current.user.typed_id,
      query: params[:q],
      lifecycle_state: params[:state],
      source_key: params[:source]
    )
  end

  def new
    render inertia: "openings/new"
  end

  def create
    result = MarketCatalog::Api.submit_manual_opening(
      workspace_id: Current.organization.typed_id,
      title: params.require(:title),
      company_name: params[:company_name],
      url: params[:url],
      location: params[:location],
      remote_policy: params[:remote_policy],
      compensation: params[:compensation],
      notes: params[:notes],
      command: command_provenance
    )

    redirect_to opening_path(result.dig(:opening, :id)), status: :see_other
  rescue MarketCatalog::Api::InvalidInput, MarketCatalog::Api::ContractViolation, ActionController::ParameterMissing
    head :unprocessable_content
  end

  def show
    render inertia: "openings/show", props: OpeningDetailQuery.call(
      workspace_id: Current.organization.typed_id,
      user_id: Current.user.typed_id,
      opening_id: params[:id]
    )
  rescue MarketCatalog::Api::NotFound
    head :not_found
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
