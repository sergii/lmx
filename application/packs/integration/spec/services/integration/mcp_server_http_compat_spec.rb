# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::Mcp::Server, "HTTP compatibility" do
  class OpenAiMcpRecordingAdapter
    attr_reader :calls

    def initialize(tools:)
      @tools = tools
      @calls = []
    end

    def tools
      @tools
    end

    def call(**attributes)
      @calls << attributes
      {
        content: [ { type: "text", text: "ok" } ],
        structuredContent: { data: {} },
        isError: false
      }
    end
  end

  let(:identity) do
    Integration::Mcp::RuntimeIdentity.new(
      workspace_id: "org_01example",
      principal: "user:serhii",
      credential: "credential:openai",
      actor: "human:serhii",
      executor: "agent:openai",
      client: "openai-mcp",
      capabilities: %w[read:openings submit:openings],
      runtime_id: "runtime-openai-http"
    )
  end
  let(:read_adapter) do
    OpenAiMcpRecordingAdapter.new(
      tools: [
        {
          name: "openings.search",
          description: "Search openings",
          inputSchema: { type: "object", properties: {}, additionalProperties: false },
          annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false }
        }
      ]
    )
  end
  let(:command_adapter) do
    OpenAiMcpRecordingAdapter.new(
      tools: [
        {
          name: "openings.submit",
          description: "Submit opening",
          inputSchema: {
            type: "object",
            properties: { title: { type: "string" } },
            required: [ "title" ],
            additionalProperties: false
          },
          annotations: {
            readOnlyHint: false,
            destructiveHint: false,
            idempotentHint: false,
            openWorldHint: false
          }
        }
      ]
    )
  end
  let(:server) do
    described_class.new(
      read_adapter:,
      command_adapter:,
      identity:,
      require_explicit_write_idempotency: true,
      allow_stateless_legacy: true
    )
  end

  it "serves legacy tools without retaining initialize state between HTTP requests" do
    response = server.call(
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "tools/list",
      "params" => { "_meta" => { "progressToken" => "openai-signal" } }
    )

    expect(response.dig("result", "tools").map { _1.fetch("name") }).to eq(
      [ "openings.search", "openings.submit" ]
    )
    expect(response.dig("result")).not_to have_key("resultType")
  end

  it "advertises a transport-neutral idempotency argument for remote writes" do
    response = server.call(
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "tools/list",
      "params" => {}
    )

    tool = response.dig("result", "tools").find { _1.fetch("name") == "openings.submit" }
    expect(tool.dig("inputSchema", "properties", described_class::IDEMPOTENCY_KEY_ARGUMENT)).to include(
      "type" => "string",
      "minLength" => 1
    )
    expect(tool.dig("inputSchema", "required")).to include(described_class::IDEMPOTENCY_KEY_ARGUMENT)
    expect(tool.dig("annotations", "idempotentHint")).to be(true)
  end

  it "uses and strips the idempotency argument before domain command dispatch" do
    response = server.call(
      "jsonrpc" => "2.0",
      "id" => "write-1",
      "method" => "tools/call",
      "params" => {
        "name" => "openings.submit",
        "arguments" => {
          "title" => "Senior Ruby Engineer",
          described_class::IDEMPOTENCY_KEY_ARGUMENT => "openai-write-123"
        },
        "_meta" => { "progressToken" => "legacy-openai-client" }
      }
    )

    expect(response.dig("result", "isError")).to be(false)
    call = command_adapter.calls.sole
    expect(call.fetch(:arguments)).to eq("title" => "Senior Ruby Engineer")
    expect(call.fetch(:context).idempotency_key).to start_with("mcp-idempotency:")
  end

  it "rejects conflicting metadata and argument idempotency keys" do
    response = server.call(
      "jsonrpc" => "2.0",
      "id" => "write-conflict",
      "method" => "tools/call",
      "params" => {
        "name" => "openings.submit",
        "arguments" => {
          "title" => "Senior Ruby Engineer",
          described_class::IDEMPOTENCY_KEY_ARGUMENT => "argument-key"
        },
        "_meta" => { described_class::IDEMPOTENCY_KEY_META_KEY => "metadata-key" }
      }
    )

    expect(response.dig("error", "code")).to eq(described_class::INVALID_PARAMS)
    expect(response.dig("error", "message")).to include("must agree")
    expect(command_adapter.calls).to be_empty
  end
end
