# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_current_request_details
  before_action :authenticate
  before_action :deny_client_portal_access_to_internal_routes
  around_action :with_current_organization

  private

  def authenticate
    redirect_to sign_in_path unless perform_authentication
  end

  def require_no_authentication
    return unless perform_authentication

    flash[:notice] = "You are already signed in"
    redirect_to root_path
  end

  def perform_authentication
    Current.session ||= Session.find_by_typed_id(cookies.signed[:session_token])
  end

  def set_current_request_details
    Current.user_agent = request.user_agent
    Current.ip_address = request.ip
  end

  def current_user
    Current.user
  end

  def current_membership
    Current.membership
  end

  def require_current_organization
    return if Current.organization

    redirect_to organizations_path
  end

  def with_current_organization
    membership = selected_membership
    return yield unless membership

    WorkspaceContext.with(membership.organization, membership: membership) { yield }
  end

  def selected_membership
    return unless Current.user

    memberships = Current.user.memberships.active.includes(:organization)
    membership = memberships.find_by(organization_id: session[:organization_id]) if session[:organization_id]
    membership ||= memberships.first if memberships.one?
    session[:organization_id] = membership.organization_id if membership
    membership
  end

  def deny_client_portal_access_to_internal_routes
    return unless Current.user
    return if controller_path.start_with?("client/") || controller_name.in?(%w[onboarding organizations organization_selections sessions])

    membership = selected_membership
    head :not_found if membership&.client_portal?
  end
end
