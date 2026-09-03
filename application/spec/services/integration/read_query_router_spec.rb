# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::Read::QueryRouter, type: :model do
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

  let(:authorization_port) do
    Class.new(Integration::Read::Ports::Authorization) do
      def authorize(_query)
        true
      end
    end.new
  end

  it "routes by the versioned contract identifier" do
    received_query = nil
    handler = lambda do |query|
      received_query = query
      Integration::Read::Ports::Result.new(data: { id: query.input.fetch(:id) })
    end
    router = described_class.new(routes: { "candidates.get.v1" => handler })
    dispatcher = Integration::Read::Dispatcher.new(query_port: router, authorization_port:)

    outcome = dispatcher.call(name: "candidates.get", context:, input: { id: "candidate_opaque" })

    expect(outcome).to be_success
    expect(outcome.data).to eq(id: "candidate_opaque")
    expect(received_query.context).to equal(context)
    expect(router.registered?(Integration::Read::Contracts.fetch("candidates.get"))).to be(true)
  end

  it "returns not_implemented when an owning-package adapter has not landed" do
    router = described_class.new(routes: {})
    dispatcher = Integration::Read::Dispatcher.new(query_port: router, authorization_port:)

    outcome = dispatcher.call(name: "applications.get", context:, input: { id: "application_opaque" })

    expect(outcome).to be_failure
    expect(outcome.error.code).to eq("not_implemented")
    expect(outcome.error.details).to eq(contract: "applications.get.v1")
  end

  it "rejects a non-callable route during composition" do
    expect do
      described_class.new(routes: { "openings.get.v1" => Object.new })
    end.to raise_error(Integration::Read::Error::InvalidInput, "query route handler must respond to call")
  end
end
