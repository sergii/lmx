# frozen_string_literal: true

class Settings::AgentAccessController < InertiaController
  before_action :require_current_organization
  before_action :require_workspace_admin

  def show
    render inertia: "settings/agent_access/show", props: {
      grants: Integration::McpOauthGrantAdmin.list_grants(
        workspace_id: Current.organization.typed_id,
        managed_by_membership_id: Current.membership.typed_id
      )
    }
  rescue Integration::McpOauthGrantAdmin::Unauthorized
    head :not_found
  end

  private

  def require_workspace_admin
    head :not_found unless Current.membership&.workspace_admin?
  end
end
