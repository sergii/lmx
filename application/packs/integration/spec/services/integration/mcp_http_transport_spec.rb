# frozen_string_literal: true

require "rails_helper"
require "stringio"

RSpec.describe Integration::Mcp::HttpTransport do
  class McpHttpRequestStub
    attr_reader :body

    def initialize(body:, headers: {}, host: "mcp.example.test", media_type: "application/json", post: true)
      @body = StringIO.new(body)
      @headers = headers
      @host = host
      @media_type = media_type
      @post = post
    end

    def post?
      @post
    end

    def host
      @host.split(":", 2).first
    end

    def host_with_port
      @host
    end

    def media_type
      @media_type
    end

    def get_header(name)
      @headers[name]
    end
  end

  let(:server) do
    instance_double(
      Integration::Mcp::Server,
      call: {
        "jsonrpc" => "2.0",
        "id" => "request-1",
        "result" => { "resultType" => "complete" }
      }
    )
  end
  let(:transport) do
    described_class.new(
      server:,
      allowed_hosts: [ "mcp.example.test" ],
      allowed_origins: [ "https://client.example.test" ]
    )
  end
  let(:modern_meta) do
    {
      Integration::Mcp::Server::PROTOCOL_VERSION_META_KEY => Integration::Mcp::Server::MODERN_PROTOCOL_VERSION,
      Integration::Mcp::Server::CLIENT_CAPABILITIES_META_KEY => {}
    }
  end

  def request_for(method:, params: {}, id: "request-1", headers: {})
    body = {
      jsonrpc: "2.0",
      id:,
      method:,
      params: params.merge(_meta: modern_meta)
    }
    default_headers = {
      "HTTP_MCP_PROTOCOL_VERSION" => Integration::Mcp::Server::MODERN_PROTOCOL_VERSION,
      "HTTP_MCP_METHOD" => method
    }
    default_headers["HTTP_MCP_NAME"] = params[:name] || params["name"] if method == "tools/call"

    McpHttpRequestStub.new(
      body: JSON.generate(body),
      headers: default_headers.merge(headers)
    )
  end

  it "dispatches a modern request only when standard HTTP headers agree with the JSON-RPC body" do
    request = request_for(method: "tools/call", params: { name: "openings.search", arguments: {} })

    status, headers, body = transport.call(request)

    expect(status).to eq(200)
    expect(headers).to include("Content-Type" => "application/json", "Cache-Control" => "no-store")
    expect(JSON.parse(body).dig("result", "resultType")).to eq("complete")
    expect(server).to have_received(:call).once
  end

  it "returns the modern header-mismatch protocol error when Mcp-Method disagrees with the body" do
    request = request_for(
      method: "tools/list",
      headers: { "HTTP_MCP_METHOD" => "tools/call" }
    )

    status, _headers, body = transport.call(request)
    payload = JSON.parse(body)

    expect(status).to eq(400)
    expect(payload.dig("error", "code")).to eq(Integration::Mcp::Server::HEADER_MISMATCH)
    expect(payload.dig("error", "data", "header")).to eq("Mcp-Method")
    expect(server).not_to have_received(:call)
  end

  it "returns unsupported-protocol-version when the HTTP protocol version is unknown" do
    request = request_for(
      method: "tools/list",
      headers: { "HTTP_MCP_PROTOCOL_VERSION" => "2099-01-01" }
    )

    status, _headers, body = transport.call(request)
    payload = JSON.parse(body)

    expect(status).to eq(400)
    expect(payload.dig("error", "code")).to eq(Integration::Mcp::Server::UNSUPPORTED_PROTOCOL_VERSION)
    expect(payload.dig("error", "data", "supported")).to eq([ "2026-07-28" ])
  end

  it "rejects a browser origin that is not explicitly allow-listed" do
    request = request_for(method: "tools/list")
    request = McpHttpRequestStub.new(
      body: request.body.string,
      headers: {
        "HTTP_MCP_PROTOCOL_VERSION" => "2026-07-28",
        "HTTP_MCP_METHOD" => "tools/list",
        "HTTP_ORIGIN" => "https://evil.example.test"
      }
    )

    status, _headers, body = transport.call(request)

    expect(status).to eq(403)
    expect(JSON.parse(body)).to eq("error" => "forbidden_origin")
    expect(server).not_to have_received(:call)
  end

  it "accepts a notification without the modern standard-header presence requirements and returns 202" do
    notification = McpHttpRequestStub.new(
      body: JSON.generate(
        jsonrpc: "2.0",
        method: "notifications/initialized",
        params: { _meta: modern_meta }
      )
    )
    allow(server).to receive(:call).and_return(nil)

    status, headers, body = transport.call(notification)

    expect(status).to eq(202)
    expect(headers).to eq("Cache-Control" => "no-store")
    expect(body).to eq("")
  end

  it "rejects non-JSON POST media types before parsing the body" do
    request = McpHttpRequestStub.new(
      body: "{}",
      media_type: "text/plain"
    )

    status, _headers, body = transport.call(request)

    expect(status).to eq(415)
    expect(JSON.parse(body)).to eq("error" => "unsupported_media_type")
  end
end
