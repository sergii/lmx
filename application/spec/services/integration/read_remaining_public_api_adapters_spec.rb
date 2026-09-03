# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Integration read public API adapters", type: :model do
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

  def read_query(name, input)
    contract = Integration::Read::Contracts.fetch(name, 1)
    Integration::Read::Query.new(contract:, context:, input:)
  end

  it "passes normalized opening search input to the Market Catalog public API seam" do
    opening_api = Class.new do
      attr_reader :searches

      def initialize
        @searches = []
      end

      def search_openings(**attributes)
        @searches << attributes
        { items: [ { id: "opening_opaque" } ], next_cursor: "cursor_opaque" }
      end
    end.new
    workspace_scope = workspace_scope_class.new
    adapter = Integration::Read::Adapters::OpeningsSearch.new(opening_api:, workspace_scope:)
    query = read_query(
      "openings.search",
      { query: "rails", filters: { "remote" => true }, cursor: "cursor_1", limit: 25 }
    )

    result = adapter.call(query)

    expect(opening_api.searches).to eq(
      [ { query: "rails", filters: { "remote" => true }, cursor: "cursor_1", limit: 25 } ]
    )
    expect(workspace_scope.contexts).to eq([ context ])
    expect(result.data).to eq(items: [ { id: "opening_opaque" } ], next_cursor: "cursor_opaque")
    expect(result.provenance).to eq(adapter: "market_catalog.public_api")
  end

  it "passes an opaque opening identifier to the Market Catalog public API seam" do
    opening_api = Class.new do
      attr_reader :ids

      def initialize
        @ids = []
      end

      def fetch_opening(opening_id:)
        @ids << opening_id
        { id: opening_id, title: "Senior Ruby Engineer" }
      end
    end.new
    adapter = Integration::Read::Adapters::OpeningsGet.new(
      opening_api:,
      workspace_scope: workspace_scope_class.new
    )

    result = adapter.call(read_query("openings.get", { id: "opening_01opaque" }))

    expect(opening_api.ids).to eq([ "opening_01opaque" ])
    expect(result.data).to eq(id: "opening_01opaque", title: "Senior Ruby Engineer")
    expect(result.provenance).to eq(adapter: "market_catalog.public_api")
  end

  it "maps configured opening not-found errors without importing their framework class" do
    missing = Class.new(StandardError)
    opening_api = Class.new do
      define_method(:fetch_opening) do |opening_id:|
        raise missing, opening_id
      end
    end.new
    adapter = Integration::Read::Adapters::OpeningsGet.new(
      opening_api:,
      workspace_scope: workspace_scope_class.new,
      not_found_errors: [ missing ]
    )

    expect do
      adapter.call(read_query("openings.get", { id: "opening_missing" }))
    end.to raise_error(Integration::Read::Error::NotFound) { |error|
      expect(error.details).to eq(contract: "openings.get.v1", id: "opening_missing")
    }
  end

  it "passes an opaque application identifier to the Personal CRM public API seam" do
    application_api = Class.new do
      attr_reader :ids

      def initialize
        @ids = []
      end

      def fetch_application(application_id:)
        @ids << application_id
        { id: application_id, stage: "applied" }
      end
    end.new
    workspace_scope = workspace_scope_class.new
    adapter = Integration::Read::Adapters::ApplicationsGet.new(application_api:, workspace_scope:)

    result = adapter.call(read_query("applications.get", { id: "application_01opaque" }))

    expect(application_api.ids).to eq([ "application_01opaque" ])
    expect(workspace_scope.contexts).to eq([ context ])
    expect(result.data).to eq(id: "application_01opaque", stage: "applied")
    expect(result.provenance).to eq(adapter: "personal_crm.public_api")
  end

  it "maps configured application not-found errors and rejects contract reuse" do
    missing = Class.new(StandardError)
    application_api = Class.new do
      define_method(:fetch_application) do |application_id:|
        raise missing, application_id
      end
    end.new
    adapter = Integration::Read::Adapters::ApplicationsGet.new(
      application_api:,
      workspace_scope: workspace_scope_class.new,
      not_found_errors: [ missing ]
    )

    expect do
      adapter.call(read_query("applications.get", { id: "application_missing" }))
    end.to raise_error(Integration::Read::Error::NotFound)

    expect do
      adapter.call(read_query("openings.get", { id: "opening_opaque" }))
    end.to raise_error(Integration::Read::Error::Unsupported)
  end
end
