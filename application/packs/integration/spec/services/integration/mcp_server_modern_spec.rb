# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::Mcp::Server, "modern runtime hardening" do
  let(:identity) do
    Integration::Mcp::RuntimeIdentity.new(
      workspace_id: "org_01example",
      principal: "user:serhii",
      credential: "credential:remote",
      actor: "human:serhii",
      executor: "agent:remote",
      client: "remote-client",
      capabilities: %w[read:openings submit:openings],
      runtime_id: "modern-hardening-spec"
    )
  end
  let(:read_adapter) do
    double(
      "read adapter",
      tools: [ { name: "openings.search", inputSchema: { type: "object" } } ],
      call: {
        content: [ { type: "text", text: "ok" } ],
        structuredContent: { data: { items: [] } },
        isError: false
      }
    )
  end
  let(:command_adapter) do
    double(
      "command adapter",
      tools: [ { name: "openings.submit", inputSchema: { type: "object" } } ],
      call: {
        content: [ { type: "text", text: "ok" } ],
        structuredContent: { data: { id: "opening_01example" } },
        isError: false
      }
    )
  end
  let(:modern_meta) do
    {
      described_class::PROTOCOL_VERSION_META_KEY => described_class::MODERN_PROTOCOL_VERSION,
      described_class::CLIENT_CAPABILITIES_META_KEY => {}
    }
  end

  it "validates the modern envelope on server/discover" do
    server = described_class.new(read_adapter:, command_adapter:, identity:)
    response = server.call(
      "jsonrpc" => "2.0",
      "id" => "discover-1",
      "method" => "server/discover",
      "params" => {
        "_meta" => {
          described_class::PROTOCOL_VERSION_META_KEY => described_class::MODERN_PROTOCOL_VERSION
        }
      }
    )

    expect(response.dig("error", "code")).to eq(described_class::INVALID_PARAMS)
    expect(response.dig("error", "message")).to include(described_class::CLIENT_CAPABILITIES_META_KEY)
  end

  it "does not expose legacy ping in the modern protocol era" do
    server = described_class.new(read_adapter:, command_adapter:, identity:)
    response = server.call(
      "jsonrpc" => "2.0",
      "id" => "ping-1",
      "method" => "ping",
      "params" => { "_meta" => modern_meta }
    )

    expect(response.dig("error", "code")).to eq(described_class::METHOD_NOT_FOUND)
  end

  it "requires explicit client idempotency for write tools when the transport requests it" do
    server = described_class.new(
      read_adapter:,
      command_adapter:,
      identity:,
      require_explicit_write_idempotency: true
    )

    response = server.call(
      "jsonrpc" => "2.0",
      "id" => "submit-1",
      "method" => "tools/call",
      "params" => {
        "name" => "openings.submit",
        "arguments" => { "title" => "Senior Ruby Engineer" },
        "_meta" => modern_meta
      }
    )

    expect(response.dig("error", "code")).to eq(described_class::INVALID_PARAMS)
    expect(response.dig("error", "message")).to include(described_class::IDEMPOTENCY_KEY_META_KEY)
    expect(command_adapter).not_to have_received(:call) if RSpec::Mocks.space.proxy_for(command_adapter).messages_received.empty?
  end
end
