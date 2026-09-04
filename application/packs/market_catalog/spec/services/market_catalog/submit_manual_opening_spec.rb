# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarketCatalog::Api, type: :model do
  let!(:organization) do
    Organization.create!(name: "Manual opening workspace", slug: "manual-opening-workspace")
  end

  it "submits a no-URL opening idempotently and keeps private capture context in the workspace event" do
    first = nil
    replay = nil

    Workspace::Api.with_workspace(workspace_id: organization.typed_id) do
      first = described_class.submit_manual_opening(
        workspace_id: organization.typed_id,
        title: "Principal Rails Engineer",
        company_name: "Private Search Co",
        location: "Europe",
        remote_policy: "Remote",
        compensation: "€90k-€110k",
        notes: "Introduced by a recruiter",
        command: command("no-url-1")
      )
      replay = described_class.submit_manual_opening(
        workspace_id: organization.typed_id,
        title: "Principal Rails Engineer",
        company_name: "Private Search Co",
        location: "Europe",
        remote_policy: "Remote",
        compensation: "€90k-€110k",
        notes: "Introduced by a recruiter",
        command: command("no-url-1")
      )
    end

    expect(replay).to eq(first)
    expect(first.fetch(:created)).to be(true)
    expect(first.fetch(:posting)).to be_nil
    expect(first.dig(:opening, :metadata)).to include(
      "ingress_interface" => "web/manual",
      "location_wording" => "Europe",
      "remote_policy_wording" => "Remote",
      "compensation_original_text" => "€90k-€110k"
    )
    expect(first.dig(:opening, :metadata)).not_to have_key("manual_notes")

    Workspace::Api.with_workspace(workspace_id: organization.typed_id) do
      expect(Platform::DomainEvent.where(event_type: "job_opening.created").count).to eq(1)
      event = Platform::DomainEvent.find_by!(event_type: "job_opening.created")
      expect(event.data).to include(
        "workspace_id" => organization.typed_id,
        "notes" => "Introduced by a recruiter"
      )
    end
  end

  it "creates URL evidence once and reuses the posting and opening for another accepted submission" do
    first = nil
    second = nil

    Workspace::Api.with_workspace(workspace_id: organization.typed_id) do
      first = described_class.submit_manual_opening(
        workspace_id: organization.typed_id,
        title: "Senior Ruby Developer",
        company_name: "Example Product",
        url: "https://jobs.dou.ua/companies/example/vacancies/987/#details",
        command: command("url-1")
      )
      second = described_class.submit_manual_opening(
        workspace_id: organization.typed_id,
        title: "Senior Ruby Developer",
        company_name: "Example Product",
        url: "https://jobs.dou.ua/companies/example/vacancies/987/#another-fragment",
        command: command("url-2")
      )
    end

    expect(first.fetch(:created)).to be(true)
    expect(second.fetch(:created)).to be(false)
    expect(second.dig(:opening, :id)).to eq(first.dig(:opening, :id))
    expect(second.dig(:posting, :id)).to eq(first.dig(:posting, :id))
    expect(first.dig(:posting, :source_key)).to eq("dou")
    expect(first.dig(:posting, :canonical_url)).to eq(
      "https://jobs.dou.ua/companies/example/vacancies/987/"
    )

    Workspace::Api.with_workspace(workspace_id: organization.typed_id) do
      expect(Platform::DomainEvent.where(event_type: "job_opening.created").count).to eq(1)
      expect(
        Platform::DomainEvent.where(event_type: "job_opening.manual_submission_recorded").count
      ).to eq(1)
    end
  end

  it "rejects non-http URLs before canonical market state changes" do
    Workspace::Api.with_workspace(workspace_id: organization.typed_id) do
      expect do
        described_class.submit_manual_opening(
          workspace_id: organization.typed_id,
          title: "Ruby Engineer",
          url: "javascript:alert(1)",
          command: command("bad-url-1")
        )
      end.to raise_error(described_class::InvalidInput, "url must use http or https")
    end
  end

  private

  def command(key)
    {
      idempotency_key: key,
      principal: "user-test",
      credential: "session-test",
      actor: "user-test",
      executor: "rspec",
      interface: "test",
      client: "rspec"
    }
  end
end
