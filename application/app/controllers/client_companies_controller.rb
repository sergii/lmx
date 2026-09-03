# frozen_string_literal: true

class ClientCompaniesController < InertiaController
  before_action :require_current_organization

  def index
    render inertia: "client_companies/index", props: { clients: ClientCompany.order(:name).map { |client| client.slice(:name).merge(id: client.typed_id) } }
  end

  def create
    client = ClientCompany.new(params.permit(:name))
    if client.save
      redirect_to projects_path, notice: "Client created"
    else
      redirect_to client_companies_path, inertia: { errors: client.errors }
    end
  end
end
