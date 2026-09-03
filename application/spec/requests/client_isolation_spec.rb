# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Client portal isolation", type: :request do
  fixtures :users

  before do
    @organization = Organization.create!(name: "TurnKey", slug: "turnkey")
    @client_one_user = User.create!(name: "Northstar manager", email: "northstar@example.com", password: "Password12345!", verified: true)
    @client_two_user = User.create!(name: "Beacon manager", email: "beacon@example.com", password: "Password12345!", verified: true)
    @client_interviewer = User.create!(name: "Northstar interviewer", email: "interviewer@example.com", password: "Password12345!", verified: true)
    @recruiter = User.create!(name: "TurnKey recruiter", email: "recruiter@example.com", password: "Password12345!", verified: true)

    Current.set(organization: @organization) do
      @client_one = ClientCompany.create!(name: "Northstar")
      @client_two = ClientCompany.create!(name: "Beacon")
      @candidate = Candidate.create!(first_name: "Ana", last_name: "Silva", email: "ana@example.com", source: "internal_referral", consent_status: "granted", notes: "Never expose this")
      @first_application = create_presented_application(@client_one)
      @second_application = create_presented_application(@client_two)
    end

    Membership.create!(user: @client_one_user, organization: @organization, client_company: @client_one, role: "client_hiring_manager")
    Membership.create!(user: @client_two_user, organization: @organization, client_company: @client_two, role: "client_hiring_manager")
    Membership.create!(user: @client_interviewer, organization: @organization, client_company: @client_one, role: "client_interviewer")
    Membership.create!(user: @recruiter, organization: @organization, role: "recruiter")
  end

  it "shows only the client's presented application with redacted fields" do
    sign_in @client_one_user

    get client_application_path(@first_application.client_portal_id)

    expect(response).to have_http_status(:success)
    expect(response.body).to include(@first_application.client_portal_id)
    expect(response.body).not_to include("ana@example.com")
    expect(response.body).not_to include("internal_referral")
    expect(response.body).not_to include("Never expose this")
    expect(response.body).not_to include(@candidate.typed_id)
  end

  it "lists only this client's presented and visible applications" do
    sign_in @client_one_user
    hidden = nil
    Current.set(organization: @organization) do
      hidden_candidate = Candidate.create!(first_name: "Hidden", last_name: "Candidate", consent_status: "unknown")
      hidden = Application.create!(candidate: hidden_candidate, job: @first_application.job, stage: "sourced", client_visible: false)
    end

    get client_applications_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include(@first_application.client_portal_id)
    expect(response.body).not_to include(@second_application.client_portal_id)
    expect(response.body).not_to include(hidden.client_portal_id)
  end

  it "makes another client's application indistinguishable from a nonexistent one" do
    sign_in @client_one_user

    get client_application_path(@second_application.client_portal_id)
    out_of_scope = [ response.status, response.body ]
    get client_application_path("application_does_not_exist")
    nonexistent = [ response.status, response.body ]

    expect(out_of_scope).to eq(nonexistent)
    expect(out_of_scope.first).to eq(404)
  end

  it "does not expose the same client-facing application id across clients" do
    sign_in @client_one_user
    get client_application_path(@first_application.client_portal_id)
    first_body = response.body

    sign_in @client_two_user
    get client_application_path(@second_application.client_portal_id)

    expect(response.body).not_to include(@first_application.client_portal_id)
    expect(first_body).not_to include(@second_application.client_portal_id)
  end

  it "closes candidate routes to client principals" do
    sign_in @client_one_user

    get candidate_path(@candidate)

    expect(response).to have_http_status(:not_found)
  end

  it "records a client hiring manager's acceptance and creates a recruiter follow-up task" do
    sign_in @client_one_user

    expect {
      post client_application_decision_path(@first_application.client_portal_id), params: {
        decision: "accepted",
        note: "Strong fit for our delivery team."
      }
    }.to change { Current.set(organization: @organization) { ClientDecision.count } }.by(1)

    expect(response).to redirect_to(client_application_path(@first_application.client_portal_id))

    Current.set(organization: @organization) do
      decision = ClientDecision.sole
      expect(decision.decision).to eq("accepted")
      expect(decision.decided_by).to eq(@client_one_user)
      expect(decision.note).to eq("Strong fit for our delivery team.")
      expect(@first_application.reload.stage).to eq("selected")
      expect(@first_application.stage_events.order(:occurred_at).last.moved_by).to eq(@client_one_user)

      task = Task.sole
      expect(task.assigned_to).to eq(@recruiter)
      expect(task.title).to include("accepted Ana Silva")
    end
  end

  it "does not let a client decide a candidate presented to another client" do
    sign_in @client_one_user

    expect {
      post client_application_decision_path(@second_application.client_portal_id), params: { decision: "rejected" }
    }.not_to change { Current.set(organization: @organization) { ClientDecision.count } }

    expect(response).to have_http_status(:not_found)
  end

  it "does not let a client interviewer record a hiring decision" do
    sign_in @client_interviewer

    expect {
      post client_application_decision_path(@first_application.client_portal_id), params: { decision: "accepted" }
    }.not_to change { Current.set(organization: @organization) { ClientDecision.count } }

    expect(response).to have_http_status(:not_found)
  end

  def create_presented_application(client)
    project = Project.create!(name: "#{client.name} project", client_company: client)
    job = Job.create!(title: "Engineer", project:)
    Application.create!(candidate: @candidate, job:, sourced_by: @recruiter, stage: "presented", client_visible: true)
  end
end
