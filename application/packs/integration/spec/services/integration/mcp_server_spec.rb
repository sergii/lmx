# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::Mcp::Server do
  class RecordingMcpAdapter
    attr_reader :calls

    def initialize(tools:, result:)
      @tools = tools
      @result = result
      @calls = []
    end

    def tools
      @tools
    end

    def call(**attributes)
      @calls << attributes
      @result
    end
  end

  let(:identity) do
    Integration::Mcp::RuntimeIdentity.new(
      workspace_id: "org_01example",
      principal: "user:serhii",
      credential: "credential:local",
      actor: "human:serhii",
      executor: "agent:chatgpt",
      client: "chatgpt",
      capabilities: %w[read:openings submit:openings]
    )
  end
  let(:read_adapter) do
    RecordingMcpAdapter.new(
      tools: [
        {
          name: "openings.search",
          description: "Search openings",
          inputSchema: { type: "object" }
        }
      ],
      result: {
        content: [ { type: "text", text: "read-result" } ],
        structuredContent: { data: { items: [] } },
        isError: false
      }
    )
  end
  let(:command_adapter) do
    RecordingMcpAdapter.new(
      tools: [
        {
          name: "openings.submit",
          description: "Submit opening",
          inputSchema: { type: "object" }
        }
      ],
      result: {
        content: [ { type: "text", text: "write-result" } ],
        structuredContent: { data: { id: "opening_01example" } },
        isError: false
      }
    )
  end
  let(:server) { described_class.new(read_adapter:, command_adapter:, identity:) }
  let(:modern_meta) do
    {
      described_class::PROTOCOL_VERSION_META_KEY => described_class::MODERN_PROTOCOL_VERSION,
      described_class::CLIENT_CAPABILITIES_META_KEY => {},
      "io.modelcontextprotocol/clientInfo" => { "name" => "RSpec", "version" => "1" }
    }
  end

  it "serves modern discovery without a handshake and stamps server identity" do
    response = server.call(
      "jsonrpc" => "2.0",
      "id" => "discover-1",
      "method" => "server/discover",
      "params" => { "_meta" => modern_meta }
    )

    expect(response.dig("result", "supportedVersions")).to eq([ "2026-07-28" ])
    expect(response.dig("result", "capabilities")).to eq("tools" => {})
    expect(response.dig("result", "resultType")).to eq("complete")
    expect(response.dig("result", "_meta", described_class::SERVER_INFO_META_KEY)).to eq(
      "name" => "lmx",
      "version" => "phase0"
    )
  end

  it "lists tools deterministically with modern cache hints" do
    response = server.call(
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "tools/list",
      "params" => { "_meta" => modern_meta }
    )

    expect(response.dig("result", "tools").map { _1.fetch("name") }).to eq(
      [ "openings.search", "openings.submit" ]
    )
    expect(response.dig("result", "ttlMs")).to eq(0)
    expect(response.dig("result", "cacheScope")).to eq("private")
    expect(response.dig("result", "resultType")).to eq("complete")
  end

  it "routes modern read and write calls through trusted Integration contexts" do
    read_response = server.call(
      "jsonrpc" => "2.0",
      "id" => "read-1",
      "method" => "tools/call",
      "params" => {
        "name" => "openings.search",
        "arguments" => { "query" => "Ruby" },
        "_meta" => modern_meta
      }
    )
    write_response = server.call(
      "jsonrpc" => "2.0",
      "id" => "write-1",
      "method" => "tools/call",
      "params" => {
        "name" => "openings.submit",
        "arguments" => { "title" => "Senior Ruby Engineer" },
        "_meta" => modern_meta
      }
    )

    expect(read_response.dig("result", "structuredContent", "data", "items")).to eq([])
    expect(write_response.dig("result", "structuredContent", "data", "id")).to eq("opening_01example")

    read_context = read_adapter.calls.fetch(0).fetch(:context)
    command_context = command_adapter.calls.fetch(0).fetch(:context)
    expect(read_context).to be_a(Integration::Read::Context)
    expect(read_context.interface).to eq("mcp")
    expect(command_context).to be_a(Integration::Command::Context)
    expect(command_context.command_id).to start_with("mcp-command:")
    expect(command_context.idempotency_key).to start_with("mcp-idempotency:")
    expect(command_context.principal).to eq("user:serhii")
  end

  it "supports the legacy initialize lifecycle on a separate stdio connection" do
    initialize_response = server.call(
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "initialize",
      "params" => {
        "protocolVersion" => "2025-11-25",
        "capabilities" => {},
        "clientInfo" => { "name" => "Legacy client", "version" => "1" }
      }
    )
    initialized = server.call(
      "jsonrpc" => "2.0",
      "method" => "notifications/initialized"
    )
    list_response = server.call(
      "jsonrpc" => "2.0",
      "id" => 2,
      "method" => "tools/list",
      "params" => {}
    )

    expect(initialize_response.dig("result", "protocolVersion")).to eq("2025-11-25")
    expect(initialize_response.dig("result", "serverInfo", "name")).to eq("lmx")
    expect(initialize_response.dig("result")).not_to have_key("resultType")
    expect(initialized).to be_nil
    expect(list_response.dig("result", "tools").length).to eq(2)
  end

  it "rejects modern calls that omit the required client capability envelope" do
    response = server.call(
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "tools/list",
      "params" => {
        "_meta" => {
          described_class::PROTOCOL_VERSION_META_KEY => described_class::MODERN_PROTOCOL_VERSION
        }
      }
    )

    expect(response.dig("error", "code")).to eq(described_class::INVALID_PARAMS)
    expect(response.dig("error", "message")).to include(described_class::CLIENT_CAPABILITIES_META_KEY)
  end

  it "rejects a lifecycle switch after modern discovery" do
    server.call(
      "jsonrpc" => "2.0",
      "id" => "discover-1",
      "method" => "server/discover",
      "params" => { "_meta" => modern_meta }
    )

    response = server.call(
      "jsonrpc" => "2.0",
      "id" => 2,
      "method" => "initialize",
      "params" => { "protocolVersion" => "2025-11-25", "capabilities" => {}, "clientInfo" => {} }
    )

    expect(response.dig("error", "code")).to eq(described_class::INVALID_REQUEST)
    expect(response.dig("error", "message")).to include("locked to modern")
  end
end
