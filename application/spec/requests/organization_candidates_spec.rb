# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organization candidate registry", type: :request do
  fixtures :users

  it "creates an organization, selects it, and adds a candidate" do
    sign_in users(:one)

    expect {
      post organizations_path, params: { name: "Acme Recruiting" }
    }.to change(Organization, :count).by(1)
      .and change(Membership, :count).by(1)

    expect(response).to redirect_to(home_path)

    job = create_job_for(Organization.last)

    post candidates_path, params: {
      first_name: "Ada", last_name: "Lovelace", email: "ada@example.com",
      location: "London", time_zone: "Europe/London", source: "Referral", consent_status: "granted", english_proficiency_level: "b2", job_id: job.typed_id
    }
    expect(response).to redirect_to(candidates_path)

    Current.set(organization: Organization.last) do
      expect(Candidate.for_organization(Organization.last).sole.english_proficiency).to have_attributes(language_code: "en", level: "b2")
    end

    get candidates_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Ada")
  end

  it "does not expose candidates from a different organization" do
    user = users(:one)
    first_organization = Organization.create!(name: "First", slug: "first")
    second_organization = Organization.create!(name: "Second", slug: "second")
    Membership.create!(user:, organization: first_organization, role: "workspace_admin")
    Membership.create!(user:, organization: second_organization, role: "workspace_admin")
    job = create_job_for(first_organization)

    sign_in user
    post organization_selection_path, params: { organization_id: first_organization.typed_id }
    post candidates_path, params: { first_name: "Private", last_name: "Candidate", consent_status: "unknown", job_id: job.typed_id }

    private_candidate = Candidate.for_organization(first_organization).find_by!(first_name: "Private", last_name: "Candidate")

    post organization_selection_path, params: { organization_id: second_organization.typed_id }
    get candidates_path

    expect(response).to have_http_status(:success)
    expect(response.body).not_to include(private_candidate.typed_id)
  end

  it "shows the selected organization's applications on the pipeline board" do
    sign_in users(:one)
    post organizations_path, params: { name: "Pipeline Recruiting" }
    job = create_job_for(Organization.last)

    post candidates_path, params: {
      first_name: "Grace", last_name: "Hopper", consent_status: "unknown", job_id: job.typed_id
    }

    get pipeline_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Grace")
    expect(response.body).to include("sourced")
  end

  it "moves an application and renders its job pipeline" do
    sign_in users(:one)
    post organizations_path, params: { name: "Move Recruiting" }
    job = create_job_for(Organization.last)
    post candidates_path, params: {
      first_name: "Katherine", last_name: "Johnson", consent_status: "unknown", job_id: job.typed_id
    }
    application = Current.set(organization: Organization.last) { Application.for_organization(Organization.last).last }

    patch application_path(application), params: { stage: "recruiter_screen", return_to: "pipeline" }

    expect(response).to redirect_to(pipeline_path)
    follow_redirect!
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Katherine")
  end

  it "fails closed when no organization context is set" do
    expect(Candidate.unscoped.count).to eq(0)
  end

  def create_job_for(organization)
    Current.set(organization:) do
      client = ClientCompany.create!(name: "#{organization.name} Client")
      project = Project.create!(name: "#{organization.name} Project", client_company: client)
      Job.create!(title: "Senior Engineer", project: project)
    end
  end
end
