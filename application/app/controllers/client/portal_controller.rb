# frozen_string_literal: true

class Client::PortalController < InertiaController
  before_action :require_current_organization
  before_action :require_client_portal_membership

  private

  def require_client_portal_membership
    head :not_found unless Current.membership&.client_portal?
  end
end
