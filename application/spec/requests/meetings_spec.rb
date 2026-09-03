# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Candidate meetings", type: :request do
  before do
    @recruiter = User.create!(name: "Recruiter", email: "meeting-recruiter@example.com", password: "Password12345!", verified: true)
    @organization = Organization.create!(name: "Meeting workspace", slug: "meeting-workspace")
    Membership.create!(user: @recruiter, organization: @organization, role: "recruiter")

    Current.set(organization: @organization) do
      client = ClientCompany.create!(name: "Meeting client")
      project = Project.create!(name: "Meeting project", client_company: client)
      job = Job.create!(title: "Platform engineer", project:)
      @candidate = Candidate.create!(first_name: "Ada", last_name: "Lovelace", consent_status: "granted")
      @application = Application.create!(candidate: @candidate, job:, sourced_by: @recruiter)
    end
  end

  it "schedules an application meeting, numbers it, and creates a linked reminder" do
    sign_in @recruiter

    expect {
      post meetings_path, params: {
        candidate_id: @candidate.typed_id,
        application_id: @application.typed_id,
        kind: "technical_interview",
        scheduled_at: 2.days.from_now.iso8601,
        duration_minutes: 60,
        meeting_url: "https://meet.example.com/ada",
        notes: "Pair-programming exercise"
      }
    }.to change { Current.set(organization: @organization) { Meeting.count } }.by(1)
      .and change { Current.set(organization: @organization) { Task.count } }.by(1)

    expect(response).to redirect_to(candidate_path(@candidate))

    Current.set(organization: @organization) do
      meeting = Meeting.sole
      expect(meeting).to have_attributes(kind: "technical_interview", status: "scheduled", sequence: 1, application: @application)
      expect(meeting.reminder_task).to have_attributes(assigned_to: @recruiter, due_on: meeting.scheduled_at.to_date)
    end
  end

  it "lists workspace meetings from the sidebar destination" do
    Current.set(organization: @organization) do
      Meeting.create!(
        candidate: @candidate,
        application: @application,
        created_by: @recruiter,
        kind: "client_interview",
        scheduled_at: 2.days.from_now
      )
    end
    sign_in @recruiter

    get meetings_path

    expect(response).to have_http_status(:success)
    expect(inertia_component).to eq("meetings/index")
    expect(response.body).to include(@candidate.typed_id)
  end

  it "marks a scheduled meeting complete and completes its reminder" do
    meeting = Current.set(organization: @organization) do
      Meeting.create!(candidate: @candidate, application: @application, created_by: @recruiter, kind: "recruiter_screen", scheduled_at: 1.day.from_now)
    end
    Current.set(organization: @organization) do
      task = Task.create!(created_by: @recruiter, assigned_to: @recruiter, title: "Recruiter screen with Ada", due_on: Date.tomorrow)
      meeting.update!(reminder_task: task)
    end
    sign_in @recruiter

    patch meeting_path(meeting), params: { status: "completed" }

    expect(response).to redirect_to(candidate_path(@candidate))
    Current.set(organization: @organization) do
      expect(meeting.reload.status).to eq("completed")
      expect(meeting.reminder_task.reload).to be_completed
    end
  end

  it "does not allow a meeting to be attached to a different candidate's application" do
    other_candidate = Current.set(organization: @organization) { Candidate.create!(first_name: "Grace", last_name: "Hopper", consent_status: "granted") }
    sign_in @recruiter

    expect {
      post meetings_path, params: {
        candidate_id: other_candidate.typed_id,
        application_id: @application.typed_id,
        kind: "recruiter_screen",
        scheduled_at: 1.day.from_now.iso8601
      }
    }.not_to change { Current.set(organization: @organization) { Meeting.count } }

    expect(response).to have_http_status(:not_found)
  end
end
