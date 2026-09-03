# frozen_string_literal: true

require "rails_helper"

RSpec.describe PersonalCrm::Api do
  let!(:workspace) { Organization.create!(name: "Personal CRM", slug: "personal-crm") }
  let!(:other_workspace) { Organization.create!(name: "Other CRM", slug: "personal-crm-other") }
  let!(:user) do
    User.create!(
      name: "Serhii User",
      email: "personal-crm@example.com",
      password: "Password12345!"
    )
  end
  let!(:membership) { Membership.create!(organization: workspace, user:, role: "workspace_admin") }
  let(:workspace_id) { workspace.typed_id }

  let!(:candidate_id) do
    WorkspaceContext.with(workspace, membership:) do
      TalentProfile::Api.create_candidate(
        first_name: "Serhii",
        last_name: "Candidate",
        linked_user_id: user.typed_id
      ).dig(:candidate, :id)
    end
  end

  let!(:opening_id) do
    MarketCatalog::Api.create_opening(
      canonical_title: "Senior Ruby Engineer",
      first_seen_at: Time.zone.parse("2026-09-03 12:00:00")
    ).fetch(:id)
  end

  it "saves an opening without inventing an Application attempt" do
    result = within_workspace do
      described_class.save_opportunity(
        workspace_id:,
        candidate_id:,
        job_opening_id: opening_id,
        command: command("save")
      )
    end

    expect(result.dig(:disposition, :state)).to eq("saved")
    expect(result.fetch(:application)).to be_nil

    within_workspace do
      expect(PersonalCrm::Application.count).to eq(0)
      expect(
        Platform::Reliability::AggregateVersion.call(
          aggregate_type: "PersonalCrm::OpportunityDisposition",
          aggregate_id: result.dig(:disposition, :id)
        )
      ).to eq(1)
    end
  end

  it "keeps save and ignore as reversible personal disposition changes with event history" do
    saved = within_workspace do
      described_class.save_opportunity(
        workspace_id:,
        candidate_id:,
        job_opening_id: opening_id,
        command: command("save")
      )
    end
    ignored = within_workspace do
      described_class.ignore_opportunity(
        workspace_id:,
        candidate_id:,
        job_opening_id: opening_id,
        command: command("ignore")
      )
    end

    expect(ignored.dig(:disposition, :id)).to eq(saved.dig(:disposition, :id))
    expect(ignored.dig(:disposition, :state)).to eq("ignored")

    within_workspace do
      expect(
        Platform::Reliability::AggregateVersion.call(
          aggregate_type: "PersonalCrm::OpportunityDisposition",
          aggregate_id: ignored.dig(:disposition, :id)
        )
      ).to eq(2)
    end
  end

  it "records one idempotent first Application attempt and marks the opportunity applied" do
    first = within_workspace do
      described_class.apply_to_opportunity(
        workspace_id:,
        candidate_id:,
        job_opening_id: opening_id,
        command: command("apply-first"),
        applied_at: Time.zone.parse("2026-09-03 14:00:00")
      )
    end
    second = within_workspace do
      described_class.apply_to_opportunity(
        workspace_id:,
        candidate_id:,
        job_opening_id: opening_id,
        command: command("apply-retry"),
        applied_at: Time.zone.parse("2026-09-03 14:05:00")
      )
    end

    expect(first.dig(:disposition, :state)).to eq("applied")
    expect(first.dig(:application, :id)).to start_with("application_attempt_")
    expect(first.dig(:application, :attempt_number)).to eq(1)
    expect(second.dig(:application, :id)).to eq(first.dig(:application, :id))

    within_workspace do
      expect(PersonalCrm::Application.count).to eq(1)
      expect(
        Platform::Reliability::AggregateVersion.call(
          aggregate_type: "PersonalCrm::Application",
          aggregate_id: first.dig(:application, :id)
        )
      ).to eq(1)
      expect(
        Platform::Reliability::AggregateVersion.call(
          aggregate_type: "PersonalCrm::OpportunityDisposition",
          aggregate_id: first.dig(:disposition, :id)
        )
      ).to eq(1)
    end
  end

  it "does not let save or ignore erase the fact that an application was recorded" do
    within_workspace do
      described_class.apply_to_opportunity(
        workspace_id:,
        candidate_id:,
        job_opening_id: opening_id,
        command: command("apply")
      )
    end

    expect do
      within_workspace do
        described_class.ignore_opportunity(
          workspace_id:,
          candidate_id:,
          job_opening_id: opening_id,
          command: command("ignore-after-apply")
        )
      end
    end.to raise_error(described_class::InvalidTransition, /cannot be moved back/)
  end

  it "keeps the schema capable of repeat Application attempts for an explicit future reapply command" do
    first = within_workspace do
      described_class.apply_to_opportunity(
        workspace_id:,
        candidate_id:,
        job_opening_id: opening_id,
        command: command("apply")
      )
    end

    second = within_workspace do
      PersonalCrm::Application.create!(
        organization_id: workspace.id,
        candidate_id:,
        job_opening_id: opening_id,
        attempt_number: 2,
        applied_at: 2.months.from_now,
        current_stage: "applied",
        channel: "manual"
      )
    end

    expect(second.attempt_number).to eq(2)
    expect(second.typed_id).not_to eq(first.dig(:application, :id))
  end

  it "keeps Personal CRM state isolated by the PostgreSQL workspace boundary" do
    applied = within_workspace do
      described_class.apply_to_opportunity(
        workspace_id:,
        candidate_id:,
        job_opening_id: opening_id,
        command: command("apply")
      )
    end

    other_view = WorkspaceContext.with(other_workspace) do
      described_class.fetch_opportunity(
        workspace_id: other_workspace.typed_id,
        candidate_id:,
        job_opening_id: opening_id
      )
    end

    expect(other_view).to eq(disposition: nil, application: nil)
    expect do
      WorkspaceContext.with(other_workspace) do
        described_class.fetch_application(application_id: applied.dig(:application, :id))
      end
    end.to raise_error(described_class::NotFound, "application not found")
  end

  private

  def within_workspace(&block)
    WorkspaceContext.with(workspace, membership:, &block)
  end

  def command(key)
    {
      command_id: "command-#{key}-#{SecureRandom.uuid}",
      idempotency_key: "personal-crm-#{key}-#{SecureRandom.uuid}",
      principal: user.typed_id,
      credential: "session:test",
      actor: user.typed_id,
      executor: user.typed_id,
      interface: "web",
      client: "lmx-test"
    }
  end
end
