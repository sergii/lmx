# frozen_string_literal: true

class Settings::McpOauthGrantsController < InertiaController
  before_action :require_current_organization
  before_action :require_workspace_admin

  def capabilities
    Integration::McpOauthGrantAdmin.update_capabilities(
      workspace_id: Current.organization.typed_id,
      grant_id: params.require(:id),
      capabilities: Array(params[:capabilities]),
      managed_by_membership_id: Current.membership.typed_id
    )

    redirect_to settings_agent_access_path, notice: "Agent capabilities updated"
  rescue Integration::McpOauthGrantAdmin::InvalidInput,
    Integration::McpOauthGrantAdmin::Unauthorized => error
    redirect_to settings_agent_access_path, alert: error.message
  rescue Integration::McpOauthGrantAdmin::NotFound
    head :not_found
  end

  def revoke
    Integration::McpOauthGrantAdmin.revoke_grant(
      workspace_id: Current.organization.typed_id,
      grant_id: params.require(:id),
      managed_by_membership_id: Current.membership.typed_id,
      reason: params[:reason]
    )

    redirect_to settings_agent_access_path, notice: "Agent access revoked"
  rescue Integration::McpOauthGrantAdmin::InvalidInput,
    Integration::McpOauthGrantAdmin::Unauthorized => error
    redirect_to settings_agent_access_path, alert: error.message
  rescue Integration::McpOauthGrantAdmin::NotFound
    head :not_found
  end

  def restore
    Integration::McpOauthGrantAdmin.restore_grant(
      workspace_id: Current.organization.typed_id,
      grant_id: params.require(:id),
      managed_by_membership_id: Current.membership.typed_id
    )

    redirect_to settings_agent_access_path, notice: "Agent access restored"
  rescue Integration::McpOauthGrantAdmin::InvalidInput,
    Integration::McpOauthGrantAdmin::Unauthorized => error
    redirect_to settings_agent_access_path, alert: error.message
  rescue Integration::McpOauthGrantAdmin::NotFound
    head :not_found
  end

  private

  def require_workspace_admin
    head :not_found unless Current.membership&.workspace_admin?
  end
end
