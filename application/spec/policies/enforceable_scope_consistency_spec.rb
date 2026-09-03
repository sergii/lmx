# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Policy scope consistency" do
  let(:binding) { EnforceableActionPolicyBinding.new }

  it "keeps Client::ApplicationPolicy#show? consistent with its client relation scope" do
    organization = Organization.create!(name: "Client scope verification", slug: "client-scope-verification")

    within_organization(organization) do
      northstar = ClientCompany.create!(name: "Northstar")
      beacon = ClientCompany.create!(name: "Beacon")
      northstar_manager = create_user("Northstar manager")
      beacon_manager = create_user("Beacon manager")
      northstar_membership = Membership.create!(user: northstar_manager, organization:, client_company: northstar, role: "client_hiring_manager")
      beacon_membership = Membership.create!(user: beacon_manager, organization:, client_company: beacon, role: "client_hiring_manager")
      candidate = Candidate.create!(first_name: "Ada", last_name: "Lovelace", consent_status: "granted")
      northstar_application = presented_application(candidate, northstar, northstar_manager)
      beacon_application = presented_application(candidate, beacon, beacon_manager)

      world = Enforceable::World.define(:client_application_scope_consistency) do
        actor(:northstar_manager) { EnforceableActor.new(northstar_manager, northstar_membership) }
        actor(:beacon_manager) { EnforceableActor.new(beacon_manager, beacon_membership) }
        subject(:northstar_presented) { northstar_application }
        subject(:beacon_presented) { beacon_application }
      end

      report = Enforceable::Runner.new(binding:, world:, policies: [ Client::ApplicationPolicy ]).run
      expect(report).not_to be_failed, report.to_s
    end
  end

  it "keeps InterviewPolicy#show? consistent with its internal relation scope" do
    organization = Organization.create!(name: "Interview scope verification", slug: "interview-scope-verification")

    within_organization(organization) do
      client = ClientCompany.create!(name: "Northstar")
      recruiter = create_user("Internal recruiter")
      client_user = create_user("Client interviewer")
      recruiter_membership = Membership.create!(user: recruiter, organization:, role: "recruiter")
      client_membership = Membership.create!(user: client_user, organization:, client_company: client, role: "client_interviewer")
      candidate = Candidate.create!(first_name: "Grace", last_name: "Hopper", consent_status: "granted")
      interview = Interview.create!(candidate:, created_by: recruiter, status: "completed", interviewer_notes: "Internal only")

      world = Enforceable::World.define(:interview_scope_consistency) do
        actor(:recruiter) { EnforceableActor.new(recruiter, recruiter_membership) }
        actor(:client_user) { EnforceableActor.new(client_user, client_membership) }
        subject(:interview) { interview }
      end

      report = Enforceable::Runner.new(binding:, world:, policies: [ InterviewPolicy ]).run
      expect(report).not_to be_failed, report.to_s
    end
  end

  private

  def within_organization(organization)
    connection = ActiveRecord::Base.connection
    Current.set(organization:) do
      connection.execute("SET app.current_organization = #{connection.quote(organization.id)}")
      yield
    ensure
      connection.execute("RESET app.current_organization")
    end
  end

  def create_user(name)
    User.create!(name:, email: "#{name.parameterize}-#{SecureRandom.hex(4)}@example.com", password: "Password12345!", verified: true)
  end

  def presented_application(candidate, client, recruiter)
    project = Project.create!(name: "#{client.name} project", client_company: client)
    job = Job.create!(title: "Engineer", project:)
    Application.create!(candidate:, job:, sourced_by: recruiter, stage: "presented", client_visible: true)
  end
end
