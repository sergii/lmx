# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::Read::Dispatcher do
  class FakeIntegrationReadQueryPort < Integration::Read::Ports::Query
    attr_reader :queries

    def initialize(error: nil)
      @queries = []
      @error = error
    end

    def call(query)
      queries << query
      raise @error if @error

      data = if query.contract.name == "openings.search"
        { items: [ { id: "job_opening_opaque" } ], next_cursor: "cursor-2" }
      else
        { id: query.input.fetch(:id) }
      end

      Integration::Read::Ports::Result.new(data:, provenance: { adapter: "fake" })
    end
  end

  class FakeIntegrationReadAuthorizationPort < Integration::Read::Ports::Authorization
    def initialize(authorized: true)
      @authorized = authorized
    end

    def authorize(_query)
      @authorized
    end
  end

  let(:query_port) { FakeIntegrationReadQueryPort.new }
  let(:authorization_port) { FakeIntegrationReadAuthorizationPort.new }
  let(:dispatcher) { described_class.new(query_port:, authorization_port:) }
  let(:context) do
    Integration::Read::Context.new(
      workspace_id: "workspace_opaque",
      principal: "user:serhii",
      credential: "session:credential-reference",
      actor: "human:serhii",
      executor: "agent:chatgpt",
      interface: "mcp",
      client: "chatgpt",
      request_id: "request-1",
      correlation_id: "correlation-1"
    )
  end

  it "publishes the versioned read contract names" do
    identifiers = Integration::Read::Contracts.all.map(&:identifier)

    expect(identifiers).to contain_exactly(
      "openings.search.v1",
      "openings.get.v1",
      "candidates.get.v1",
      "candidates.profile.v1",
      "matches.get.v1",
      "applications.get.v1"
    )
  end

  it "passes query and provenance context through the query port" do
    outcome = dispatcher.call(
      name: "openings.search",
      context:,
      input: { query: "ruby", filters: { "remote" => true }, limit: 20 }
    )

    expect(outcome).to be_success
    expect(query_port.queries.one?).to be(true)
    expect(query_port.queries.first).to have_attributes(
      context:,
      input: { query: "ruby", filters: { "remote" => true }, limit: 20 }
    )
    expect(outcome.data).to eq(
      items: [ { id: "job_opening_opaque" } ],
      next_cursor: "cursor-2"
    )
    expect(outcome.provenance).to eq(adapter: "fake")
  end

  it "keeps typed identifiers opaque instead of parsing through ActiveRecord" do
    opaque_id = "future_candidate_prefix_01hopaque"

    outcome = dispatcher.call(name: "candidates.get", context:, input: { id: opaque_id })

    expect(outcome).to be_success
    expect(query_port.queries.first.input).to eq(id: opaque_id)
    expect(outcome.data).to eq(id: opaque_id)
  end

  it "retains security provenance internally without echoing credential references" do
    outcome = dispatcher.call(name: "openings.get", context:, input: { id: "job_opening_opaque" })

    expect(outcome.context).to equal(context)
    expect(query_port.queries.first.context.credential).to eq("session:credential-reference")
    expect(outcome.to_h.fetch(:context)).to include(
      principal: "user:serhii",
      actor: "human:serhii",
      executor: "agent:chatgpt",
      interface: "mcp",
      client: "chatgpt"
    )
    expect(outcome.to_h.fetch(:context)).not_to have_key(:credential)
  end

  it "returns invalid_input for malformed query input" do
    outcome = dispatcher.call(name: "openings.search", context:, input: { limit: 0 })

    expect(outcome).to be_failure
    expect(outcome.error.code).to eq("invalid_input")
    expect(query_port.queries).to be_empty
  end

  it "returns unauthenticated when principal or credential provenance is missing" do
    unauthenticated_context = Integration::Read::Context.new(
      workspace_id: "workspace_opaque",
      principal: nil,
      credential: nil,
      actor: "human:serhii",
      executor: "agent:chatgpt",
      interface: "mcp",
      client: "chatgpt"
    )

    outcome = dispatcher.call(name: "openings.get", context: unauthenticated_context, input: { id: "job_opening_opaque" })

    expect(outcome.error.code).to eq("unauthenticated")
    expect(query_port.queries).to be_empty
  end

  it "returns unauthorized before invoking the domain query port" do
    unauthorized_dispatcher = described_class.new(
      query_port:,
      authorization_port: FakeIntegrationReadAuthorizationPort.new(authorized: false)
    )

    outcome = unauthorized_dispatcher.call(
      name: "applications.get",
      context:,
      input: { id: "application_opaque" }
    )

    expect(outcome.error.code).to eq("unauthorized")
    expect(query_port.queries).to be_empty
  end

  it "preserves not_found semantics from an owning package adapter" do
    not_found_port = FakeIntegrationReadQueryPort.new(error: Integration::Read::Error::NotFound.new)
    not_found_dispatcher = described_class.new(query_port: not_found_port, authorization_port:)

    outcome = not_found_dispatcher.call(
      name: "openings.get",
      context:,
      input: { id: "job_opening_missing" }
    )

    expect(outcome.error.code).to eq("not_found")
  end

  it "distinguishes unsupported versions from not implemented ports" do
    unsupported = dispatcher.call(
      name: "openings.get",
      version: 2,
      context:,
      input: { id: "job_opening_opaque" }
    )

    not_implemented_dispatcher = described_class.new(
      query_port: Integration::Read::Ports::Query.new,
      authorization_port:
    )
    not_implemented = not_implemented_dispatcher.call(
      name: "openings.get",
      context:,
      input: { id: "job_opening_opaque" }
    )

    expect(unsupported.error.code).to eq("unsupported")
    expect(not_implemented.error.code).to eq("not_implemented")
  end
end
