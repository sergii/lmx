# frozen_string_literal: true

require "rails_helper"

RSpec.describe Candidates::Erasure do
  fixtures :users

  it "anonymizes candidate PII, removes applications and events, and leaves an ID-only audit event" do
    organization = Organization.create!(name: "Erasure", slug: "erasure")
    Current.set(organization:) do
      client = ClientCompany.create!(name: "Client")
      project = Project.create!(name: "Project", client_company: client)
      job = Job.create!(title: "Engineer", project:)
      candidate = Candidate.create!(first_name: "Ana", last_name: "Silva", email: "ana@example.com", source: "Referral", consent_status: "granted", notes: "Sensitive")
      application = Application.create!(candidate:, job:, stage: "presented", client_visible: true)
      ApplicationStageEvent.create!(application:, to_stage: "presented", occurred_at: Time.current)

      described_class.call(candidate:, reason: "data_subject_request")

      expect(candidate.reload).to have_attributes(first_name: "Erased", last_name: "Candidate", email: nil, source: nil, notes: nil)
      expect(candidate.erased_at).to be_present
      expect(Application.where(candidate:)).to be_empty
      expect(ApplicationStageEvent.where(application_id: application.id)).to be_empty
      event = AuditEvent.where(subject_id: candidate.id, action: "candidate.erased").last
      expect(event.metadata).to eq("reason" => "data_subject_request")
      expect(event.to_json).not_to include("ana@example.com")
      expect { described_class.call(candidate: candidate.reload, reason: "data_subject_request") }.not_to raise_error
    end
  end
end
