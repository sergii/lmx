# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::Mcp::ReadAdapter, type: :model do
  let(:query_port) do
    Class.new(Integration::Read::Ports::Query) do
      def call(query)
        data = if query.contract.name == "openings.search"
          { items: [ { id: "job_opening_opaque" } ], next_cursor: nil }
        else
          { id: query.input.fetch(:id) }
        end

        Integration::Read::Ports::Result.new(data:, provenance: { adapter: "fake" })
      end
    end.new
  end

  let(:authorization_port) do
    Class.new(Integration::Read::Ports::Authorization) do
      def authorize(_query)
        true
      end
    end.new
  end

  let(:dispatcher) do
    Integration::Read::Dispatcher.new(query_port:, authorization_port:)
  end

  let(:adapter) { described_class.new(dispatcher:) }
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

  it "publishes the read tools from the shared contracts" do
    tools = adapter.tools

    expect(tools.map { |tool| tool.fetch(:name) }).to eq(
      [
        "openings.search",
        "openings.get",
        "candidates.get",
        "candidates.profile",
        "matches.get",
        "applications.get"
      ]
    )
    expect(tools.find { |tool| tool[:name] == "openings.search" }.fetch(:inputSchema)).to include(
      "type" => "object",
      "additionalProperties" => false
    )
    expect(tools.find { |tool| tool[:name] == "candidates.get" }.dig(:inputSchema, "required")).to eq([ "id" ])
    expect(tools.find { |tool| tool[:name] == "candidates.profile" }.dig(:inputSchema, "required")).to eq([ "id" ])
  end

  it "maps a successful read outcome to MCP structured content" do
    result = adapter.call(name: "openings.get", arguments: { id: "job_opening_opaque" }, context:)

    expect(result[:isError]).to be(false)
    expect(result.dig(:structuredContent, :data)).to eq(id: "job_opening_opaque")
    expect(result.dig(:structuredContent, :context, :interface)).to eq("mcp")
    expect(result.dig(:structuredContent, :context)).not_to have_key(:credential)
    expect(JSON.parse(result.dig(:content, 0, :text))).to eq(JSON.parse(JSON.generate(result[:structuredContent])))
  end

  it "returns contract failures as MCP tool errors instead of transport exceptions" do
    result = adapter.call(name: "candidates.get", arguments: {}, context:)

    expect(result[:isError]).to be(true)
    expect(result.dig(:structuredContent, :error, :code)).to eq("invalid_input")
  end

  it "keeps unsupported tools inside the stable error envelope" do
    result = adapter.call(name: "unknown.read", arguments: {}, context:)

    expect(result[:isError]).to be(true)
    expect(result.dig(:structuredContent, :error, :code)).to eq("unsupported")
  end
end
