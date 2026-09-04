# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::McpRuntime do
  it "builds the shared read and command stacks from trusted process configuration" do
    environment = {
      "LMX_MCP_WORKSPACE_ID" => "org_01example",
      "LMX_MCP_PRINCIPAL" => "user:serhii",
      "LMX_MCP_CREDENTIAL" => "credential:stdio",
      "LMX_MCP_ACTOR" => "human:serhii",
      "LMX_MCP_EXECUTOR" => "agent:codex",
      "LMX_MCP_CLIENT" => "codex",
      "LMX_MCP_CAPABILITIES" => "read:openings, submit:openings assess:matches"
    }
    read_adapter = instance_double(Integration::Mcp::ReadAdapter)
    command_adapter = instance_double(Integration::Mcp::CommandAdapter)
    allow(Integration::ReadStack).to receive(:build).and_return(read_adapter)
    allow(Integration::CommandStack).to receive(:build).and_return(command_adapter)
    allow(Integration::Mcp::Server).to receive(:new).and_call_original
    allow(read_adapter).to receive(:tools).and_return([])
    allow(command_adapter).to receive(:tools).and_return([])

    server = described_class.build(environment:)

    expect(server).to be_a(Integration::Mcp::Server)
    expect(Integration::ReadStack).to have_received(:build) do |credential_source:|
      context = Integration::Read::Context.new(
        workspace_id: "org_01example",
        principal: "user:serhii",
        credential: "credential:stdio",
        actor: "human:serhii",
        executor: "agent:codex",
        interface: "mcp",
        client: "codex"
      )
      expect(credential_source.resolve(context).fetch(:capabilities)).to eq(
        [ "assess:matches", "read:openings", "submit:openings" ]
      )
    end
    expect(Integration::CommandStack).to have_received(:build)
  end

  it "fails closed when required process identity is missing" do
    expect do
      described_class.build(environment: {})
    end.to raise_error(ArgumentError, /LMX_MCP_WORKSPACE_ID is required/)
  end
end
