# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::Read::Adapters::CandidatesGet, type: :model do
  let(:candidate_api_class) do
    Class.new do
      attr_reader :candidate_ids

      def initialize(error: nil)
        @candidate_ids = []
        @error = error
      end

      def fetch_candidate(candidate_id:)
        raise @error if @error

        @candidate_ids << candidate_id
        {
          id: candidate_id,
          first_name: "Serhii",
          profile_version: nil
        }.freeze
      end
    end
  end

  let(:workspace_scope_class) do
    Class.new(Integration::Read::Ports::WorkspaceScope) do
      attr_reader :contexts

      def initialize
        @contexts = []
      end

      def call(context)
        @contexts << context
        yield
      end
    end
  end

  let(:context) do
    Integration::Read::Context.new(
      workspace_id: "workspace_opaque",
      principal: "user:serhii",
      credential: "credential_opaque",
      actor: "human:serhii",
      executor: "agent:generic",
      interface: "mcp",
      client: "generic-client"
    )
  end

  def query(name: "candidates.get", input: { id: "candidate_opaque" })
    contract = Integration::Read::Contracts.fetch(name, 1)
    Integration::Read::Query.new(contract:, context:, input:)
  end

  it "calls the candidate public API inside the explicit workspace scope" do
    candidate_api = candidate_api_class.new
    workspace_scope = workspace_scope_class.new
    adapter = described_class.new(candidate_api:, workspace_scope:)

    result = adapter.call(query)

    expect(candidate_api.candidate_ids).to eq([ "candidate_opaque" ])
    expect(workspace_scope.contexts).to eq([ context ])
    expect(result.data).to eq(
      id: "candidate_opaque",
      first_name: "Serhii",
      profile_version: nil
    )
    expect(result.provenance).to eq(adapter: "talent_profile.public_api")
  end

  it "passes the opaque typed identifier through without parsing it in Integration" do
    candidate_api = candidate_api_class.new
    adapter = described_class.new(candidate_api:, workspace_scope: workspace_scope_class.new)

    adapter.call(query(input: { id: "candidate_01opaque" }))

    expect(candidate_api.candidate_ids).to eq([ "candidate_01opaque" ])
  end

  it "maps only configured public API not-found exceptions" do
    missing_candidate = Class.new(StandardError)
    candidate_api = candidate_api_class.new(error: missing_candidate.new("missing"))
    adapter = described_class.new(
      candidate_api:,
      workspace_scope: workspace_scope_class.new,
      not_found_errors: [ missing_candidate ]
    )

    expect { adapter.call(query) }.to raise_error(Integration::Read::Error::NotFound) { |error|
      expect(error.details).to eq(
        contract: "candidates.get.v1",
        id: "candidate_opaque"
      )
    }
  end

  it "does not swallow unexpected public API failures" do
    failure = RuntimeError.new("unexpected failure")
    candidate_api = candidate_api_class.new(error: failure)
    adapter = described_class.new(
      candidate_api:,
      workspace_scope: workspace_scope_class.new
    )

    expect { adapter.call(query) }.to raise_error(failure)
  end

  it "cannot be reused for another query contract" do
    candidate_api = candidate_api_class.new
    adapter = described_class.new(candidate_api:, workspace_scope: workspace_scope_class.new)

    expect do
      adapter.call(query(name: "openings.get", input: { id: "opening_opaque" }))
    end.to raise_error(Integration::Read::Error::Unsupported)
  end
end
