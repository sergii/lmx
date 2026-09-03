# frozen_string_literal: true

class OrganizationsController < InertiaController
  def index
    render inertia: "organizations/index", props: {
      organizations: Current.user.memberships.active.includes(:organization).map do |membership|
        {
          id: membership.organization.typed_id,
          name: membership.organization.name,
          role: membership.role,
          logo_url: logo_url_for(membership.organization)
        }
      end
    }
  end

  def new
    render inertia: "organizations/new"
  end

  def create
    organization = nil

    Organization.transaction do
      organization = Organization.new(name: organization_params[:name], slug: unique_slug(organization_params[:name]))
      organization.logo.attach(organization_params[:logo]) if organization_params[:logo].present?
      organization.save!
      Current.user.memberships.create!(organization:, role: "workspace_admin")
    end

    session[:organization_id] = organization.id
    redirect_to home_path, notice: "Workspace created"
  rescue ActiveRecord::RecordInvalid => error
    redirect_to new_organization_path, inertia: { errors: error.record.errors }
  end

  private

  def organization_params
    params.permit(:name, :logo)
  end

  def unique_slug(name)
    base = name.to_s.parameterize.presence || "organization"
    slug = base
    suffix = 2
    while Organization.exists?(slug:)
      slug = "#{base}-#{suffix}"
      suffix += 1
    end
    slug
  end

  def logo_url_for(organization)
    rails_blob_url(organization.logo) if organization.logo.attached?
  end
end
