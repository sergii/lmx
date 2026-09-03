# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Recruiter tasks", type: :request do
  it "creates and completes a tenant-scoped reminder" do
    user = User.create!(name: "Recruiter", email: "recruiter@example.com", password: "Password12345!", verified: true)
    organization = Organization.create!(name: "Task workspace", slug: "task-workspace")
    Membership.create!(user:, organization:, role: "recruiter")
    sign_in user

    get tasks_path
    expect(response).to have_http_status(:success)
    expect(inertia_component).to eq("tasks/index")

    post tasks_path, params: { title: "Follow up with Ada", due_on: Date.current }
    expect(response).to redirect_to(tasks_path)

    task = Current.set(organization:) { Task.sole }
    expect(task).to have_attributes(title: "Follow up with Ada", assigned_to: user, created_by: user)

    patch task_path(task.typed_id), params: { completed: true }
    expect(response).to redirect_to(tasks_path)
    expect(task.reload).to be_completed
  end
end
