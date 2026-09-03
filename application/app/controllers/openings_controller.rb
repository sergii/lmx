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
end
