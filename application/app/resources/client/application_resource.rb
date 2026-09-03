# frozen_string_literal: true

class Client::ApplicationResource
  include Alba::Resource

  attribute :id do |application|
    application.client_portal_id
  end

  attributes :stage

  attribute :decision_open do |application|
    application.client_decision.nil? && application.stage.in?(%w[presented client_interviews])
  end

  attribute :decision do |application|
    next unless application.client_decision

    {
      outcome: application.client_decision.decision,
      note: application.client_decision.note,
      decided_at: application.client_decision.decided_at.iso8601
    }
  end

  attribute :role do |application|
    application.job.title
  end

  attribute :project do |application|
    application.job.project.name
  end

  attribute :candidate do |application|
    candidate = application.candidate
    {
      name: application.stage == "selected" ? "#{candidate.first_name} #{candidate.last_name}" : "Candidate",
      skills: candidate.skills
    }
  end
end
