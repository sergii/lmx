# frozen_string_literal: true

class Settings::WorkspacesController < InertiaController
  before_action :require_current_organization
  before_action :require_workspace_admin

  def show
    render inertia: "settings/workspaces/show", props: { workspace: workspace_props }
  end

  def update
    Current.organization.update!(workspace_params)
    redirect_to settings_workspace_path, notice: "Workspace branding updated"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to settings_workspace_path, inertia: { errors: e.record.errors }
  end

  private

  def require_workspace_admin
    head :not_found unless Current.membership&.workspace_admin?
  end

  def workspace_params
    params.permit(:name, :logo)
  end

  def workspace_props
    {
      name: Current.organization.name,
      logo_url: (rails_blob_url(Current.organization.logo) if Current.organization.logo.attached?)
    }
  end
end
