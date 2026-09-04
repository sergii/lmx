# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MCP applications.get read path" do
  let(:context) do
    Integration::Mcp::ContextFactory.new.call(
      workspace_id: "org_opaque",
      principal: "user:serhii",
      credential: "credential_opaque",
      actor: "human:serhii",
      executor: "agent:generic",
      client: "generic-client",
      request_id: "request_opaque",
      correlation_id: "correlation_opaque"
    )
  end

  let(:application_api) do
    Class.new do
      attr_reader :requests

      def initialize
        @requests = []
      end

      def fetch_application(workspace_id:, application_id:)
        @requests << { workspace_id:, application_id: }
        {
          id: application_id,
          workspace_id:,
          candidate_id: "candidate_opaque",
          job_opening_id: "opening_opaque",
          via_posting_id: "posting_opaque",
          stage: "screening",
          next_action: "Prepare for technical interview"
        }
      end
    end.new
  end

  let(:workspace_api) do
    Class.new do
      attr_reader :workspace_ids

      def initialize
        @workspace_ids = []
      end

      def with_workspace(workspace_id:)
        @workspace_ids << workspace_id
        yield
      end
    end.new
  end

  let(:workspace_scope) do
    Integration::Read::Adapters::PublicApiWorkspaceScope.new(workspace_api:)
  end

  let(:capabilities) { [ "read:applications" ] }
  let(:credential_source) do
    source_capabilities = capabilities

    Class.new do
      attr_reader :contexts

      define_method(:initialize) do
        @contexts = []
      end

      define_method(:resolve) do |resolved_context|
        @contexts << resolved_context
        {
          workspace_id: resolved_context.workspace_id,
          principal: resolved_context.principal,
          credential: resolved_context.credential,
          capabilities: source_capabilities
        }
      end
    end.new
  end

  let(:capability_resolver) do
    Integration::Read::CredentialCapabilityResolver.new(credential_source:)
  end

  let(:application_query) do
    Integration::Read::Adapters::ApplicationsGet.new(
      application_api:,
      workspace_scope:
    )
  end

  let(:query_router) do
    Integration::Read::QueryRouter.new(
      routes: { "applications.get.v1" => application_query }
    )
  end

  let(:authorization_port) do
    Integration::Read::CapabilityAuthorization.new(capability_resolver:)
  end

  let(:dispatcher) do
    Integration::Read::Dispatcher.new(
      query_port: query_router,
      authorization_port:
    )
  end

  let(:adapter) { Integration::Mcp::ReadAdapter.new(dispatcher:) }

  it "executes the canonical application read path with workspace provenance" do
    application_id = "application_attempt_opaque"

    result = adapter.call(
      name: "applications.get",
      arguments: { id: application_id },
      context:
    )

    expect(result[:isError]).to be(false)
    expect(result.dig(:structuredContent, :data)).to include(
      id: application_id,
      workspace_id: "org_opaque",
      candidate_id: "candidate_opaque",
      job_opening_id: "opening_opaque",
      stage: "screening",
      next_action: "Prepare for technical interview"
    )
    expect(result.dig(:structuredContent, :meta, :provenance)).to eq(
      adapter: "personal_crm.public_api"
    )
    expect(result.dig(:structuredContent, :context)).to include(
      workspace_id: "org_opaque",
      actor: "human:serhii",
      executor: "agent:generic",
      interface: "mcp",
      client: "generic-client"
    )
    expect(application_api.requests).to eq(
      [ { workspace_id: "org_opaque", application_id: } ]
    )
    expect(credential_source.contexts).to eq([ context ])
    expect(workspace_api.workspace_ids).to eq([ "org_opaque" ])
  end

  context "without the required capability" do
    let(:capabilities) { [] }

    it "fails closed before entering workspace scope or calling Personal CRM" do
      result = adapter.call(
        name: "applications.get",
        arguments: { id: "application_attempt_opaque" },
        context:
      )

      expect(result[:isError]).to be(true)
      expect(result.dig(:structuredContent, :error, :code)).to eq("unauthorized")
      expect(credential_source.contexts).to eq([ context ])
      expect(application_api.requests).to be_empty
      expect(workspace_api.workspace_ids).to be_empty
    end
  end
end
