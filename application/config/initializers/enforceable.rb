# frozen_string_literal: true

# Enforceable is a test-only guardrail. It verifies that declared point checks
# and their relation scopes agree, without participating in runtime authorization.
if Rails.env.test? && defined?(Enforceable)
  require Rails.root.join("lib/enforceable/lmx_action_policy_binding")

  Enforceable.configure do |config|
    config.world = :lmx
    config.binding = Enforceable::LmxActionPolicyBinding.new
  end

  verification_fixtures = {}
  build_fixtures = lambda do
    verification_fixtures[:lmx] ||= begin
      organization = Organization.create!(
        name: "Enforceable LMX verification",
        slug: "enforceable-lmx-#{SecureRandom.hex(6)}"
      )

      Current.organization = organization
      connection = ActiveRecord::Base.connection
      connection.execute("SET app.current_organization = #{connection.quote(organization.id)}")

      client = ClientCompany.create!(name: "Verification client")
      other_client = ClientCompany.create!(name: "Other verification client")
      recruiter = User.create!(
        name: "Verification recruiter",
        email: "enforceable-recruiter-#{SecureRandom.hex(6)}@example.test",
        password: "Password12345!",
        verified: true
      )
      client_user = User.create!(
        name: "Verification client user",
        email: "enforceable-client-#{SecureRandom.hex(6)}@example.test",
        password: "Password12345!",
        verified: true
      )
      recruiter_membership = Membership.create!(user: recruiter, organization:, role: "recruiter")
      client_membership = Membership.create!(
        user: client_user,
        organization:,
        client_company: client,
        role: "client_hiring_manager"
      )
      candidate = Candidate.create!(first_name: "Verification", last_name: "Candidate", consent_status: "granted")
      project = Project.create!(name: "Verification project", client_company: client)
      job = Job.create!(title: "Verification engineer", project:)
      application = Application.create!(
        candidate:,
        job:,
        sourced_by: recruiter,
        stage: "presented",
        client_visible: true
      )
      other_project = Project.create!(name: "Other verification project", client_company: other_client)
      other_job = Job.create!(title: "Other verification engineer", project: other_project)
      other_application = Application.create!(
        candidate:,
        job: other_job,
        sourced_by: recruiter,
        stage: "presented",
        client_visible: true
      )
      interview = Interview.create!(
        candidate:,
        application:,
        created_by: recruiter,
        status: "completed",
        interviewer_notes: "Internal verification fixture"
      )

      {
        recruiter: Enforceable::LmxActionPolicyBinding::Actor.new(recruiter, recruiter_membership),
        client_user: Enforceable::LmxActionPolicyBinding::Actor.new(client_user, client_membership),
        application:,
        other_application:,
        interview:
      }
    end
  end

  Enforceable::World.define(:lmx) do
    actor(:recruiter) { build_fixtures.call.fetch(:recruiter) }
    actor(:client_user) { build_fixtures.call.fetch(:client_user) }
    subject(:client_application) { build_fixtures.call.fetch(:application) }
    subject(:other_client_application) { build_fixtures.call.fetch(:other_application) }
    subject(:interview) { build_fixtures.call.fetch(:interview) }
  end
end
