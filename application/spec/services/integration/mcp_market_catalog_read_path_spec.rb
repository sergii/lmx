# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MCP Market Catalog read path" do
  let(:observed_at) { Time.zone.parse("2026-09-02 13:30:00") }

  let(:company) do
    MarketCatalog::Api.create_company(
      canonical_name: "Example Labs",
      website_url: "https://example.test"
    )
  end

  let(:opening) do
    MarketCatalog::Api.create_opening(
      canonical_title: "Senior Ruby Engineer",
      primary_company_id: company.fetch(:id),
      first_seen_at: observed_at
    )
  end

  let(:context) do
    Integration::Mcp::ContextFactory.new.call(
      workspace_id: "workspace_opaque",
      principal: "user:serhii",
      credential: "credential_opaque",
      actor: "human:serhii",
      executor: "agent:generic",
      client: "generic-client",
      request_id: "request_opaque",
      correlation_id: "correlation_opaque"
    )
  end

  let(:workspace_scope) do
    Class.new do
      attr_reader :contexts

      def initialize
        @contexts = []
      end

      def call(context)
        @contexts << context
        yield
      end
    end.new
  end

  let(:capability_resolver) do
    Class.new do
      def resolve(context)
        Integration::Read::CapabilityGrant.new(
          workspace_id: context.workspace_id,
          principal: context.principal,
          credential: context.credential,
          capabilities: [ "read:openings" ]
        )
      end
    end.new
  end

  let(:query_router) do
    Integration::Read::QueryRouter.new(
      routes: {
        "openings.search.v1" => Integration::Read::Adapters::OpeningsSearch.new(
          opening_api: MarketCatalog::Api,
          workspace_scope:
        ),
        "openings.get.v1" => Integration::Read::Adapters::OpeningsGet.new(
          opening_api: MarketCatalog::Api,
          workspace_scope:
        )
      }
    )
  end

  let(:dispatcher) do
    Integration::Read::Dispatcher.new(
      query_port: query_router,
      authorization_port: Integration::Read::CapabilityAuthorization.new(
        capability_resolver:
      )
    )
  end

  let(:adapter) { Integration::Mcp::ReadAdapter.new(dispatcher:) }

  it "searches real Market Catalog openings through the complete MCP read path" do
    opening_id = opening.fetch(:id)

    result = adapter.call(
      name: "openings.search",
      arguments: { query: "ruby", limit: 10 },
      context:
    )

    expect(result[:isError]).to be(false)
    expect(result.dig(:structuredContent, :data, :items)).to contain_exactly(
      include(
        id: opening_id,
        primary_company_id: company.fetch(:id),
        canonical_title: "Senior Ruby Engineer",
        lifecycle_state: "open"
      )
    )
    expect(result.dig(:structuredContent, :meta, :provenance)).to eq(
      adapter: "market_catalog.public_api"
    )
    expect(workspace_scope.contexts).to eq([ context ])
  end

  it "fetches a real Market Catalog opening by opaque typed identifier" do
    opening_id = opening.fetch(:id)

    result = adapter.call(
      name: "openings.get",
      arguments: { id: opening_id },
      context:
    )

    expect(result[:isError]).to be(false)
    expect(result.dig(:structuredContent, :data)).to include(
      id: opening_id,
      primary_company_id: company.fetch(:id),
      canonical_title: "Senior Ruby Engineer",
      lifecycle_state: "open"
    )
    expect(result.dig(:structuredContent, :meta, :provenance)).to eq(
      adapter: "market_catalog.public_api"
    )
    expect(workspace_scope.contexts).to eq([ context ])
  end
end
