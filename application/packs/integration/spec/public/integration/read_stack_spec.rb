# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::ReadStack do
  let(:workspace_api) do
    Class.new do
      attr_reader :workspace_ids

      def initialize
        @workspace_ids = []
      end

      def with_workspace(workspace_id:)
        @workspace_ids << workspace_id
        yield
      end
    end.new
  end

  let(:candidate_api) do
    Class.new do
      attr_reader :candidate_ids, :profile_candidate_ids

      def initialize
        @candidate_ids = []
        @profile_candidate_ids = []
      end

      def fetch_candidate(candidate_id:)
        @candidate_ids << candidate_id
        { id: candidate_id, first_name: "Ada", last_name: "Lovelace" }
      end

      def fetch_latest_profile(candidate_id:)
        @profile_candidate_ids << candidate_id
        {
          id: "candidate_profile_version_opaque",
          candidate_id:,
          version_number: 3,
          profile: { "skills" => [ "Ruby", "Rails" ] },
          content_digest: "a" * 64
        }
      end
    end.new
  end

  let(:opening_api) do
    Class.new do
      attr_reader :opening_ids, :searches

      def initialize
        @opening_ids = []
        @searches = []
      end

      def fetch_opening(opening_id:)
        @opening_ids << opening_id
        { id: opening_id, canonical_title: "Senior Ruby Engineer" }
      end

      def search_openings(**attributes)
        @searches << attributes
        { items: [ { id: "opening_result" } ] }
      end
    end.new
  end

  let(:match_api) do
    Class.new do
      attr_reader :requests

      def initialize
        @requests = []
      end

      def fetch_match_assessment(workspace_id:, assessment_id:)
        @requests << { workspace_id:, assessment_id: }
        {
          id: assessment_id,
          workspace_id:,
          version_number: 2,
          opportunity_score: 81.25,
          action_priority: 92.5,
          recommendation: "Apply now"
        }
      end
    end.new
  end

  let(:credential_source) do
    Class.new do
      attr_reader :contexts

      def initialize
        @contexts = []
      end

      def resolve(context)
        @contexts << context
        {
          workspace_id: context.workspace_id,
          principal: context.principal,
          credential: context.credential,
          capabilities: [ "read:openings", "read:candidates", "read:matches", "read:applications" ]
        }
      end
    end.new
  end

  let(:context) do
    Integration::Mcp::ContextFactory.new.call(
      workspace_id: "org_opaque",
      principal: "user:serhii",
      credential: "credential_opaque",
      actor: "human:serhii",
      executor: "agent:chatgpt",
      client: "chatgpt"
    )
  end

  subject(:adapter) do
    described_class.build(
      credential_source:,
      workspace_api:,
      candidate_api:,
      opening_api:,
      match_api:
    )
  end

  it "composes the production-shaped candidate read path" do
    result = adapter.call(
      name: "candidates.get",
      arguments: { id: "candidate_opaque" },
      context:
    )

    expect(result[:isError]).to be(false)
    expect(result.dig(:structuredContent, :data)).to include(
      id: "candidate_opaque",
      first_name: "Ada",
      last_name: "Lovelace"
    )
    expect(result.dig(:structuredContent, :meta, :provenance)).to eq(
      adapter: "talent_profile.public_api"
    )
    expect(candidate_api.candidate_ids).to eq([ "candidate_opaque" ])
    expect(workspace_api.workspace_ids).to eq([ "org_opaque" ])
    expect(credential_source.contexts).to eq([ context ])
  end

  it "composes candidates.profile through the latest Talent Profile snapshot" do
    result = adapter.call(
      name: "candidates.profile",
      arguments: { id: "candidate_opaque" },
      context:
    )

    expect(result[:isError]).to be(false)
    expect(result.dig(:structuredContent, :data)).to include(
      id: "candidate_profile_version_opaque",
      candidate_id: "candidate_opaque",
      version_number: 3,
      profile: { "skills" => [ "Ruby", "Rails" ] },
      content_digest: "a" * 64
    )
    expect(result.dig(:structuredContent, :meta, :provenance)).to eq(
      adapter: "talent_profile.public_api"
    )
    expect(candidate_api.profile_candidate_ids).to eq([ "candidate_opaque" ])
    expect(workspace_api.workspace_ids).to eq([ "org_opaque" ])
  end

  it "composes both Market Catalog read contracts" do
    get_result = adapter.call(
      name: "openings.get",
      arguments: { id: "opening_opaque" },
      context:
    )
    search_result = adapter.call(
      name: "openings.search",
      arguments: { query: "rails", filters: { "remote" => true }, limit: 10 },
      context:
    )

    expect(get_result[:isError]).to be(false)
    expect(get_result.dig(:structuredContent, :data, :canonical_title)).to eq("Senior Ruby Engineer")
    expect(search_result[:isError]).to be(false)
    expect(search_result.dig(:structuredContent, :data, :items)).to eq([ { id: "opening_result" } ])
    expect(opening_api.opening_ids).to eq([ "opening_opaque" ])
    expect(opening_api.searches).to eq([ { query: "rails", filters: { "remote" => true }, limit: 10 } ])
    expect(workspace_api.workspace_ids).to eq([ "org_opaque", "org_opaque" ])
  end

  it "composes matches.get through the Intelligence public API" do
    result = adapter.call(
      name: "matches.get",
      arguments: { id: "match_assessment_opaque" },
      context:
    )

    expect(result[:isError]).to be(false)
    expect(result.dig(:structuredContent, :data)).to include(
      id: "match_assessment_opaque",
      workspace_id: "org_opaque",
      version_number: 2,
      opportunity_score: 81.25,
      action_priority: 92.5,
      recommendation: "Apply now"
    )
    expect(result.dig(:structuredContent, :meta, :provenance)).to eq(
      adapter: "intelligence.public_api"
    )
    expect(match_api.requests).to eq(
      [ { workspace_id: "org_opaque", assessment_id: "match_assessment_opaque" } ]
    )
    expect(workspace_api.workspace_ids).to eq([ "org_opaque" ])
  end

  it "keeps applications.get explicitly unimplemented until canonical Personal CRM exists" do
    result = adapter.call(
      name: "applications.get",
      arguments: { id: "application_opaque" },
      context:
    )

    expect(result[:isError]).to be(true)
    expect(result.dig(:structuredContent, :error)).to include(
      code: "not_implemented",
      details: { contract: "applications.get.v1" }
    )
    expect(workspace_api.workspace_ids).to be_empty
  end
end
