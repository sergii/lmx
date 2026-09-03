# frozen_string_literal: true

class OrganizationSelectionsController < InertiaController
  def create
    organization_id = Organization.typed_id_value(params[:organization_id])
    membership = Current.user.memberships.active.find_by(organization_id:)
    return redirect_to organizations_path, alert: "Organization access was not found" unless membership

    session[:organization_id] = membership.organization_id
    redirect_to home_path
  end
end
