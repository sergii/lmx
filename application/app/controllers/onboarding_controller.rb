# frozen_string_literal: true

class OnboardingController < InertiaController
  before_action :redirect_to_workspace_if_present, only: %i[profile update_profile workspace create_workspace]
  before_action :require_current_workspace, only: %i[use_cases update_use_cases team complete]

  USE_CASES = {
    "sourcing" => "Sourcing talent",
    "active_roles" => "Managing active roles",
    "client_collaboration" => "Collaborating with clients",
    "talent_pipeline" => "Building a talent pipeline"
  }.freeze

  def profile
    render inertia: "onboarding/profile", props: { user: Current.user.slice(:name, :email) }
  end

  def update_profile
    Current.user.update!(profile_params)
    redirect_to onboarding_workspace_path
  rescue ActiveRecord::RecordInvalid => e
    redirect_to onboarding_profile_path, inertia: { errors: e.record.errors }
  end

  def workspace
    render inertia: "onboarding/workspace", props: { suggested_name: Current.user.name.presence&.then { "#{_1}'s workspace" } }
  end

  def create_workspace
    organization = nil

    Organization.transaction do
      organization = Organization.new(name: workspace_params[:name], slug: unique_slug(workspace_params[:name]))
      organization.logo.attach(workspace_params[:logo]) if workspace_params[:logo].present?
      organization.save!
      Current.user.memberships.create!(organization:, role: "workspace_admin")
    end

    session[:organization_id] = organization.id
    redirect_to onboarding_use_cases_path
  rescue ActiveRecord::RecordInvalid => e
    redirect_to onboarding_workspace_path, inertia: { errors: e.record.errors }
  end

  def use_cases
    render inertia: "onboarding/use-cases", props: { selected_use_cases: Current.organization.onboarding_use_cases, use_cases: USE_CASES }
  end

  def update_use_cases
    Current.organization.update!(onboarding_use_cases: use_case_params)
    redirect_to onboarding_team_path
  rescue ActiveRecord::RecordInvalid => e
    redirect_to onboarding_use_cases_path, inertia: { errors: e.record.errors }
  end

  def team
    render inertia: "onboarding/team", props: { workspace_name: Current.organization.name }
  end

  def complete
    Current.user.update!(onboarding_completed_at: Time.current)
    redirect_to home_path, notice: "Your workspace is ready"
  end

  private

  def redirect_to_workspace_if_present
    redirect_to home_path if Current.user.memberships.active.exists?
  end

  def require_current_workspace
    return if Current.organization

    redirect_to onboarding_workspace_path
  end

  def profile_params
    params.permit(:name)
  end

  def workspace_params
    params.permit(:name, :logo)
  end

  def use_case_params
    params.fetch(:use_cases, []).filter_map { |value| value if USE_CASES.key?(value) }.uniq.first(5)
  end

  def unique_slug(name)
    base = name.to_s.parameterize.presence || "workspace"
    slug = base
    suffix = 2

    while Organization.exists?(slug:)
      slug = "#{base}-#{suffix}"
      suffix += 1
    end

    slug
  end
end
