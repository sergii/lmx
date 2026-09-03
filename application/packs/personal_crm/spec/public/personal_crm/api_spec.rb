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

  it "moves an ignored opening back to saved and projects a new application attempt" do
    WorkspaceContext.with(organization, membership:) do
      described_class.ignore_opening(
        workspace_id: organization.typed_id,
        candidate_id: candidate.fetch(:id),
        job_opening_id: opening.fetch(:id),
        command: command("ignore-1")
      )

      result = described_class.start_application(
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
      projection = PersonalCrm::ApplicationProjection.find_by!(
        organization_id: organization.id,
        application_id: result.dig(:application, :id)
      )

      expect(context.dig(:disposition, :state)).to eq("saved")
      expect(attempt.fetch(:stage)).to eq("applying")
      expect(attempt.fetch(:next_action)).to eq("Submit application")
      expect(projection.stage).to eq("applying")
      expect(projection.next_action).to eq("Submit application")
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
      expect(PersonalCrm::ApplicationProjection.where(organization_id: organization.id).count).to eq(2)
      expect(
        Platform::DomainEvent.where(event_type: described_class::APPLICATION_STARTED).count
      ).to eq(2)
    end
  end

  it "changes stage through an immutable event and keeps Opening Detail reduction current" do
    WorkspaceContext.with(organization, membership:) do
      application = described_class.start_application(
        workspace_id: organization.typed_id,
        candidate_id: candidate.fetch(:id),
        job_opening_id: opening.fetch(:id),
        command: command("apply-stage-1")
      ).fetch(:application)

      expect do
        described_class.advance_application(
          workspace_id: organization.typed_id,
          application_id: application.fetch(:id),
          stage: "applied",
          command: command("advance-1")
        )
      end.to change(
        Platform::DomainEvent.where(event_type: described_class::APPLICATION_STAGE_CHANGED), :count
      ).by(1).and change(
        Platform::OutboxMessage.where(message_type: described_class::APPLICATION_STAGE_CHANGED), :count
      ).by(1)

      projected = described_class.fetch_application(
        workspace_id: organization.typed_id,
        application_id: application.fetch(:id)
      )
      context = described_class.fetch_opening_context(
        workspace_id: organization.typed_id,
        candidate_id: candidate.fetch(:id),
        job_opening_id: opening.fetch(:id)
      )

      expect(projected.fetch(:stage)).to eq("applied")
      expect(projected.fetch(:applied_at)).to be_present
      expect(context.dig(:applications, 0, :stage)).to eq("applied")
      expect(context.dig(:applications, 0, :applied_at)).to be_present
    end
  end

  it "updates the next action through an immutable event" do
    WorkspaceContext.with(organization, membership:) do
      application = described_class.start_application(
        workspace_id: organization.typed_id,
        candidate_id: candidate.fetch(:id),
        job_opening_id: opening.fetch(:id),
        command: command("apply-action-1")
      ).fetch(:application)
      due_at = 2.days.from_now.change(usec: 0)

      described_class.set_next_action(
        workspace_id: organization.typed_id,
        application_id: application.fetch(:id),
        next_action: "Follow up with recruiter",
        next_action_at: due_at.iso8601,
        command: command("next-action-1")
      )

      projected = described_class.fetch_application(
        workspace_id: organization.typed_id,
        application_id: application.fetch(:id)
      )
      context = described_class.fetch_opening_context(
        workspace_id: organization.typed_id,
        candidate_id: candidate.fetch(:id),
        job_opening_id: opening.fetch(:id)
      )

      expect(projected.fetch(:next_action)).to eq("Follow up with recruiter")
      expect(projected.fetch(:next_action_at)).to be_within(1.second).of(due_at)
      expect(context.dig(:applications, 0, :next_action)).to eq("Follow up with recruiter")
      expect(
        Platform::DomainEvent.where(event_type: described_class::APPLICATION_NEXT_ACTION_CHANGED).count
      ).to eq(1)
    end
  end

  it "queries application projections by candidate and stage" do
    WorkspaceContext.with(organization, membership:) do
      first = described_class.start_application(
        workspace_id: organization.typed_id,
        candidate_id: candidate.fetch(:id),
        job_opening_id: opening.fetch(:id),
        command: command("apply-search-1")
      ).fetch(:application)
      second = described_class.start_application(
        workspace_id: organization.typed_id,
        candidate_id: candidate.fetch(:id),
        job_opening_id: opening.fetch(:id),
        command: command("apply-search-2")
      ).fetch(:application)
      described_class.advance_application(
        workspace_id: organization.typed_id,
        application_id: second.fetch(:id),
        stage: "screening",
        command: command("advance-search-1")
      )

      applying = described_class.search_applications(
        workspace_id: organization.typed_id,
        candidate_id: candidate.fetch(:id),
        stages: [ "applying" ]
      )
      screening = described_class.search_applications(
        workspace_id: organization.typed_id,
        candidate_id: candidate.fetch(:id),
        stages: [ "screening" ]
      )

      expect(applying.map { _1.fetch(:id) }).to eq([ first.fetch(:id) ])
      expect(screening.map { _1.fetch(:id) }).to eq([ second.fetch(:id) ])
      expect(described_class.application_stages).to include("applying", "screening", "offer")
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
