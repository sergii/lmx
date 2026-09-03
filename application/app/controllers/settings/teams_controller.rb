# frozen_string_literal: true

class Settings::TeamsController < InertiaController
  before_action :require_current_organization
  before_action :require_workspace_admin

  def show
    render inertia: "settings/teams/show", props: {
      members: Current.organization.memberships.includes(:user).order(:created_at).map { |membership| member_props(membership) },
      invitations: Current.organization.workspace_invitations.where(status: "pending").order(created_at: :desc).map { |invitation| invitation_props(invitation) },
      roles: WorkspaceInvitation::ROLES.index_with { _1.humanize }
    }
  end

  def create
    invitation = Current.organization.workspace_invitations.new(
      email: params.require(:email),
      role: params.require(:role),
      invited_by: Current.user
    )

    if invitation.save
      redirect_to settings_team_path, notice: "Invitation created for #{invitation.email}"
    else
      redirect_to settings_team_path, inertia: { errors: invitation.errors }
    end
  end

  private

  def require_workspace_admin
    head :not_found unless Current.membership&.workspace_admin?
  end

  def member_props(membership)
    {
      id: membership.typed_id,
      name: membership.user.name,
      email: membership.user.email,
      role: membership.role
    }
  end

  def invitation_props(invitation)
    {
      id: invitation.typed_id,
      email: invitation.email,
      role: invitation.role,
      created_at: invitation.created_at.iso8601
    }
  end
end
