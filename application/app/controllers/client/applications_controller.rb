# frozen_string_literal: true

class Client::ApplicationsController < Client::PortalController
  def index
    authorize! Application, to: :index?, with: Client::ApplicationPolicy
    applications = authorized_scope(Application.includes(:candidate, :client_decision, job: :project), with: Client::ApplicationPolicy)
    render inertia: "client/applications/index", props: { applications: Client::ApplicationResource.new(applications).serializable_hash }
  end

  def show
    applications = authorized_scope(Application.includes(:candidate, :client_decision, job: :project), with: Client::ApplicationPolicy)
    application = applications.find_by(client_portal_id: params[:id])
    return head :not_found unless application

    authorize! application, to: :show?, with: Client::ApplicationPolicy
    render inertia: "client/applications/show", props: {
      application: Client::ApplicationResource.new(application).serializable_hash,
      can_decide: Current.membership.role == "client_hiring_manager"
    }
  end
end
