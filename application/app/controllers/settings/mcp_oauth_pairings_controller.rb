# frozen_string_literal: true

class Settings::McpOauthPairingsController < InertiaController
  before_action :require_current_organization
  before_action :require_workspace_admin

  def show
    ticket = pairing_ticket

    render inertia: "settings/agent_access/pair", props: {
      pairing: pairing_props(ticket),
      members: pairable_members
    }
  rescue Integration::McpOauthPairing::InvalidTicket,
    Integration::McpOauthPairing::InvalidInput
    redirect_to settings_agent_access_path, alert: "This MCP pairing link is invalid or has expired"
  rescue Integration::McpOauthResourceMetadata::ConfigurationError
    redirect_to settings_agent_access_path, alert: "MCP OAuth pairing is not configured"
  end

  def create
    Integration::McpOauthPairing.approve(
      token: pairing_token,
      resource: oauth_resource,
      workspace_id: Current.organization.typed_id,
      membership_id: params.require(:membership_id),
      capabilities: Array(params[:capabilities]),
      managed_by_membership_id: Current.membership.typed_id
    )

    redirect_to settings_agent_access_path, notice: "MCP agent connected"
  rescue Integration::McpOauthPairing::InvalidTicket
    redirect_to settings_agent_access_path, alert: "This MCP pairing link is invalid or has expired"
  rescue Integration::McpOauthPairing::Conflict
    redirect_to settings_agent_access_path, alert: "This OAuth identity is already paired"
  rescue Integration::McpOauthPairing::InvalidInput,
    Integration::McpOauthPairing::NotFound,
    Integration::McpOauthPairing::Unauthorized => error
    redirect_to settings_mcp_oauth_pairing_path(pairing_token: pairing_token), alert: error.message
  rescue Integration::McpOauthResourceMetadata::ConfigurationError
    redirect_to settings_agent_access_path, alert: "MCP OAuth pairing is not configured"
  end

  private

  def pairing_ticket
    Integration::McpOauthPairing.describe(
      token: pairing_token,
      resource: oauth_resource
    )
  end

  def pairing_token
    params[:pairing_token].to_s
  end

  def oauth_resource
    Integration::McpOauthResourceMetadata.build(environment: ENV).resource.to_s
  end

  def pairing_props(ticket)
    {
      token: pairing_token,
      issuer: ticket.issuer,
      subject: ticket.subject,
      client_id: ticket.client_id,
      resource: ticket.resource,
      scopes: ticket.scopes,
      pairable_capabilities: Integration::McpOauthPairing.pairable_capabilities(ticket.scopes),
      issued_at: ticket.issued_at.iso8601(6),
      expires_at: ticket.expires_at.iso8601(6)
    }
  end

  def pairable_members
    Current.organization.memberships.active.includes(:user).order(:created_at).filter_map do |membership|
      next if membership.client_portal?

      {
        id: membership.typed_id,
        user_id: membership.user.typed_id,
        name: membership.user.name,
        email: membership.user.email,
        role: membership.role
      }
    end
  end

  def require_workspace_admin
    head :not_found unless Current.membership&.workspace_admin?
  end
end
