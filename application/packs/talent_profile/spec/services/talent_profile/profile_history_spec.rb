# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Talent Profile version history" do
  let!(:workspace) { Organization.create!(name: "Profile history", slug: "profile-history") }

  it "returns canonical profile versions newest first as immutable snapshots" do
    candidate = WorkspaceContext.with(workspace) do
      TalentProfile::Api.create_candidate(
        first_name: "Ada",
        last_name: "Lovelace",
        profile: { skills: [ "Ruby" ] }
      ).fetch(:candidate)
    end

    second = WorkspaceContext.with(workspace) do
      TalentProfile::Api.create_profile_version(
        candidate_id: candidate.fetch(:id),
        profile: { skills: [ "Ruby", "Rails" ], target: "Senior Rails" }
      )
    end

    versions = WorkspaceContext.with(workspace) do
      TalentProfile::Api.fetch_profile_versions(candidate_id: candidate.fetch(:id))
    end

    expect(versions.map { _1.fetch(:version_number) }).to eq([ 2, 1 ])
    expect(versions.first).to eq(second)
    expect(versions).to be_frozen
    expect(versions.first.fetch(:profile)).to be_frozen
  end
end
