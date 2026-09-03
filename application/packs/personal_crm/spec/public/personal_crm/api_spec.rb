# frozen_string_literal: true

require "rails_helper"

RSpec.describe PersonalCrm::Api, type: :model do
  let!(:user) do
    User.create!(
      name: "Ada Lovelace",
      email: "ada-personal-crm@example.com",
      password: "Password12345!",
      verified: true
    )
  end
  let!(:organization) { Organization.create!(name: "Personal CRM workspace", slug: "personal-crm-workspace") }
  let!(:membership) { Membership.create!(user:, organization:, role: "workspace_admin") }
  let!(:opening) do
    MarketCatalog::Api.create_opening(
      canonical_title: "Senior Ruby Engineer",
      first_seen_at: Time.current
    )
  end
  let!(:candidate) do
    WorkspaceContext.with(organization, membership:) do
      TalentProfile::Api.create_candidate(
        first_name: "Ada",
        last_name: "Lovelace",
        linked_user_id: user.typed_id,
        profile: { skills: [ "Ruby", "Rails" ] }
      ).fetch(:candidate)
    end
  end

  it "saves an opening idempotently through Inbox, Event Store, and Outbox" do
    WorkspaceContext.with(organization, membership:) do
      expect do
        described_class.save_opening(
          workspace_id: organization.typed_id,
          candidate_id: candidate.fetch(:id),
          job_opening_id: opening.fetch(:id),
          command: command("save-1")
        )
      end.to change(
        Platform::InboxMessage.where(command_name: "personal_crm.save_opening"), :count
      ).by(1).and change(
        Platform::DomainEvent.where(event_type: described_class::OPENING_SAVED), :count
      ).by(1).and change(
        Platform::OutboxMessage.where(message_type: described_class::OPENING_SAVED), :count
      ).by(1)

      event = Platform::DomainEvent.find_by!(event_type: described_class::OPENING_SAVED)
      expect(event.aggregate_type).to eq(described_class::AGGREGATE_TYPE)
      expect(event.data).to include(
        "workspace_id" => organization.typed_id,
        "candidate_id" => candidate.fetch(:id),
        "job_opening_id" => opening.fetch(:id),
        "state" => "saved",
        "previous_state" => nil
      )

      expect do
        described_class.save_opening(
          workspace_id: organization.typed_id,
          candidate_id: candidate.fetch(:id),
          job_opening_id: opening.fetch(:id),
          command: command("save-1")
        )
      end.to change(
        Platform::InboxMessage.where(command_name: "personal_crm.save_opening"), :count
      ).by(0).and change(
        Platform::DomainEvent.where(event_type: described_class::OPENING_SAVED), :count
      ).by(0).and change(
        Platform::OutboxMessage.where(message_type: described_class::OPENING_SAVED), :count
      ).by(0)

      context = described_class.fetch_opening_context(
        workspace_id: organization.typed_id,
        candidate_id: candidate.fetch(:id),
        job_opening_id: opening.fetch(:id)
      )
      expect(context.dig(:disposition, :state)).to eq("saved")
      expect(context.fetch(:applications)).to be_empty
    end
  end

  it "moves an ignored opening back to saved when an application attempt starts" do
    WorkspaceContext.with(organization, membership:) do
      described_class.ignore_opening(
        workspace_id: organization.typed_id,
        candidate_id: candidate.fetch(:id),
        job_opening_id: opening.fetch(:id),
        command: command("ignore-1")
      )

      described_class.start_application(
        workspace_id: organization.typed_id,
        candidate_id: candidate.fetch(:id),
        job_opening_id: opening.fetch(:id),
        command: command("apply-1")
      )

      context = described_class.fetch_opening_context(
        workspace_id: organization.typed_id,
        candidate_id: candidate.fetch(:id),
        job_opening_id: opening.fetch(:id)
      )
      attempt = context.fetch(:applications).first

      expect(context.dig(:disposition, :state)).to eq("saved")
      expect(attempt.fetch(:stage)).to eq("applying")
      expect(attempt.fetch(:next_action)).to eq("Submit application")
      expect(
        Platform::DomainEvent.where(
          event_type: [
            described_class::OPENING_IGNORED,
            described_class::OPENING_SAVED,
            described_class::APPLICATION_STARTED
          ]
        ).pluck(:event_type)
      ).to contain_exactly(
        described_class::OPENING_IGNORED,
        described_class::OPENING_SAVED,
        described_class::APPLICATION_STARTED
      )
    end
  end

  it "allows repeat application attempts while replaying the same command only once" do
    WorkspaceContext.with(organization, membership:) do
      attributes = {
        workspace_id: organization.typed_id,
        candidate_id: candidate.fetch(:id),
        job_opening_id: opening.fetch(:id)
      }

      described_class.start_application(**attributes, command: command("apply-repeat-1"))
      described_class.start_application(**attributes, command: command("apply-repeat-1"))
      described_class.start_application(**attributes, command: command("apply-repeat-2"))

      context = described_class.fetch_opening_context(**attributes)
      expect(context.fetch(:applications).size).to eq(2)
      expect(context.fetch(:applications).map { _1.fetch(:id) }.uniq.size).to eq(2)
      expect(
        Platform::DomainEvent.where(event_type: described_class::APPLICATION_STARTED).count
      ).to eq(2)
    end
  end

  private

  def command(key)
    {
      idempotency_key: key,
      principal: user.typed_id,
      credential: "test-credential",
      actor: user.typed_id,
      executor: "rspec",
      interface: "test",
      client: "rspec"
    }
  end
end
