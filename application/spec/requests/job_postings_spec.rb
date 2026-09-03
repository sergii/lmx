# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Job briefs and postings", type: :request do
  before do
    @organization = Organization.create!(name: "Northstar Recruiting", slug: "northstar-recruiting")
    @other_organization = Organization.create!(name: "Other Recruiting", slug: "other-recruiting")
    @recruiter = User.create!(name: "Riley Recruiter", email: "riley@example.com", password: "Password12345!", verified: true)
    @client_user = User.create!(name: "Client Manager", email: "manager@example.com", password: "Password12345!", verified: true)

    Current.set(organization: @organization) do
      client = ClientCompany.create!(name: "Northstar Labs")
      project = Project.create!(name: "Platform modernization", client_company: client)
      @job = Job.create!(title: "Senior Full-Stack Engineer", project:, status: "open")
      @client = client
    end

    Current.set(organization: @other_organization) do
      other_client = ClientCompany.create!(name: "Other Labs")
      other_project = Project.create!(name: "Other project", client_company: other_client)
      @other_job = Job.create!(title: "Other Engineer", project: other_project, status: "open")
    end

    Membership.create!(user: @recruiter, organization: @organization, role: "recruiter")
    Membership.create!(user: @client_user, organization: @organization, client_company: @client, role: "client_hiring_manager")
  end

  it "lets an internal recruiter publish a reviewed sourcing brief and link a public posting" do
    sign_in @recruiter

    expect do
      post job_sourcing_brief_path(@job), params: {
        status: "approved",
        summary: "Own the product surface and collaborate closely with design.",
        must_haves: [ "React, TypeScript", "Product delivery" ],
        nice_to_haves: [ "Ruby on Rails" ],
        exclusions: [ "Agency-only experience" ],
        search_queries: [ "React engineer Toronto" ],
        location_preferences: [ "Canada" ],
        language_requirement: "English B2+",
        interview_focus: "Product judgement and collaboration"
      }
    end.to change { Current.set(organization: @organization) { SourcingBrief.count } }.by(1)

    expect(response).to redirect_to(job_path(@job))

    Current.set(organization: @organization) do
      brief = @job.reload.sourcing_brief
      expect(brief).to have_attributes(status: "approved", approved_by: @recruiter, language_requirement: "English B2+")
      expect(brief.must_haves).to contain_exactly("React", "TypeScript", "Product delivery")
    end

    expect do
      post job_postings_path, params: {
        job_id: @job.typed_id,
        channel: "careers_site",
        status: "published",
        title: "Senior Full-Stack Engineer",
        public_url: "https://careers.example.test/jobs/senior-full-stack-engineer",
        content_snapshot: "A recruiter-reviewed snapshot of the published role."
      }
    end.to change { Current.set(organization: @organization) { JobPosting.count } }.by(1)

    expect(response).to redirect_to(job_path(@job))

    Current.set(organization: @organization) do
      posting = @job.reload.job_postings.sole
      expect(posting).to have_attributes(channel: "careers_site", status: "published", organization: @organization)
      expect(posting.published_at).to be_present
    end
  end

  it "does not let a recruiter create a posting for another workspace's job" do
    sign_in @recruiter

    expect do
      post job_postings_path, params: {
        job_id: @other_job.typed_id,
        channel: "careers_site",
        status: "draft",
        title: "Attempted cross-workspace posting",
        public_url: "https://careers.example.test/jobs/other"
      }
    end.not_to change { Current.set(organization: @other_organization) { JobPosting.count } }

    expect(response).to have_http_status(:not_found)
  end

  it "updates an existing posting when the same URL is submitted again" do
    Current.set(organization: @organization) do
      @posting = @job.job_postings.create!(
        channel: "careers_site", status: "draft", title: "Original title",
        public_url: "https://careers.example.test/jobs/senior-full-stack-engineer"
      )
    end
    sign_in @recruiter

    expect do
      post job_postings_path, params: {
        job_id: @job.typed_id,
        channel: "careers_site",
        status: "published",
        title: "Reviewed title",
        public_url: @posting.public_url,
        content_snapshot: "Reviewed public posting content."
      }
    end.not_to change { Current.set(organization: @organization) { JobPosting.count } }

    expect(response).to redirect_to(job_path(@job))
    Current.set(organization: @organization) do
      expect(@posting.reload).to have_attributes(status: "published", title: "Reviewed title", content_snapshot: "Reviewed public posting content.")
    end
  end

  it "keeps internal job briefs and posting links closed to client portal users" do
    sign_in @client_user

    get job_path(@job)

    expect(response).to have_http_status(:not_found)
  end
end
