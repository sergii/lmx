# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Interview assessment isolation", type: :request do
  before do
    @organization = Organization.create!(name: "Interview workspace", slug: "interview-workspace")
    @other_organization = Organization.create!(name: "Other workspace", slug: "other-interview-workspace")
    @assessor = User.create!(name: "Internal assessor", email: "assessor@example.com", password: "Password12345!", verified: true)
    @other_assessor = User.create!(name: "Other assessor", email: "other-assessor@example.com", password: "Password12345!", verified: true)
    @client_user = User.create!(name: "Client manager", email: "client-manager@example.com", password: "Password12345!", verified: true)

    Current.set(organization: @organization) do
      @client = ClientCompany.create!(name: "Northstar")
      project = Project.create!(name: "Modernization", client_company: @client)
      job = Job.create!(title: "Senior engineer", project:)
      @candidate = Candidate.create!(first_name: "Ada", last_name: "Lovelace", consent_status: "granted", notes: "Internal source note")
      @application = Application.create!(candidate: @candidate, job:, sourced_by: @assessor, stage: "technical_interview")
      @interview = Interview.create!(candidate: @candidate, application: @application, created_by: @assessor, status: "completed", interviewer_notes: "Internal technical feedback", transcript: "Private transcript text")
    end

    Current.set(organization: @other_organization) do
      other_client = ClientCompany.create!(name: "Elsewhere")
      Membership.create!(user: @other_assessor, organization: @other_organization, role: "recruiter")
      other_client
    end
    Membership.create!(user: @assessor, organization: @organization, role: "recruiter")
    Membership.create!(user: @client_user, organization: @organization, client_company: @client, role: "client_hiring_manager")
  end

  it "lets an internal assessor create and read an attributed assessment" do
    sign_in @assessor

    expect {
      post interview_assessments_path(@interview), params: {
        status: "submitted", rating: 4, recommendation: "Advance", overall_comments: "Strong systems thinking."
      }
    }.to change { Current.set(organization: @organization) { InterviewAssessment.count } }.by(1)

    expect(response).to redirect_to(interview_path(@interview))
    assessment = Current.set(organization: @organization) { InterviewAssessment.sole }
    expect(assessment).to have_attributes(assessor: @assessor, status: "submitted", rating: 4, recommendation: "Advance")

    get interview_path(@interview)

    expect(response).to have_http_status(:success)
    expect(inertia_component).to eq("interviews/show")
    expect(response.body).to include("Internal technical feedback", "Private transcript text", "Strong systems thinking.")
  end

  it "makes an interview unavailable to a client principal and indistinguishable from a missing record" do
    sign_in @client_user

    get interview_path(@interview)
    denied = [ response.status, response.body ]
    get interview_path("interview_00000000000000000000000000")
    missing = [ response.status, response.body ]

    expect(denied).to eq(missing)
    expect(denied.first).to eq(404)
    expect(denied.last).not_to include("Private transcript text")
  end

  it "makes another workspace's interview indistinguishable from a missing record" do
    sign_in @other_assessor

    get interview_path(@interview)
    denied = [ response.status, response.body ]
    get interview_path("interview_00000000000000000000000000")
    missing = [ response.status, response.body ]

    expect(denied).to eq(missing)
    expect(denied.first).to eq(404)
  end

  it "does not allow an assessment for a cancelled meeting" do
    cancelled_meeting = Current.set(organization: @organization) do
      Meeting.create!(candidate: @candidate, application: @application, created_by: @assessor, kind: "technical_interview", status: "cancelled", scheduled_at: 1.day.ago)
    end
    cancelled_interview = Current.set(organization: @organization) do
      Interview.new(candidate: @candidate, application: @application, meeting: cancelled_meeting, created_by: @assessor, status: "completed")
    end
    expect(cancelled_interview).not_to be_valid
    expect(cancelled_interview.errors[:meeting]).to include("cannot be cancelled")
  end
end
