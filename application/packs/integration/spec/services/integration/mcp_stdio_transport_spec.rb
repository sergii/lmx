# frozen_string_literal: true

require "json"
require "rails_helper"
require "stringio"

RSpec.describe Integration::Mcp::StdioTransport do
  it "reads newline-delimited JSON-RPC and writes only protocol responses to stdout" do
    server = instance_double(Integration::Mcp::Server)
    input = StringIO.new("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"ping\",\"params\":{\"_meta\":{\"io.modelcontextprotocol/protocolVersion\":\"2026-07-28\",\"io.modelcontextprotocol/clientCapabilities\":{}}}}\n")
    output = StringIO.new
    error = StringIO.new
    allow(server).to receive(:call).and_return(
      "jsonrpc" => "2.0",
      "id" => 1,
      "result" => { "resultType" => "complete" }
    )

    described_class.new(server:, input:, output:, error:).open

    expect(JSON.parse(output.string)).to eq(
      "jsonrpc" => "2.0",
      "id" => 1,
      "result" => { "resultType" => "complete" }
    )
    expect(error.string).to be_empty
  end

  it "returns a JSON-RPC parse error for malformed input without logging to stdout" do
    server = instance_double(Integration::Mcp::Server)
    input = StringIO.new("{not-json}\n")
    output = StringIO.new
    error = StringIO.new

    described_class.new(server:, input:, output:, error:).open

    response = JSON.parse(output.string)
    expect(response.dig("error", "code")).to eq(Integration::Mcp::Server::PARSE_ERROR)
    expect(response.dig("error", "message")).to eq("Parse error")
    expect(error.string).to be_empty
  end

  it "does not write a response for accepted notifications" do
    server = instance_double(Integration::Mcp::Server)
    input = StringIO.new("{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}\n")
    output = StringIO.new
    allow(server).to receive(:call).and_return(nil)

    described_class.new(server:, input:, output:, error: StringIO.new).open

    expect(output.string).to be_empty
  end
end
