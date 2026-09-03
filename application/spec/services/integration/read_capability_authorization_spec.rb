# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::Read::CapabilityAuthorization, type: :model do
  let(:resolver_class) do
    Class.new(Integration::Read::Ports::CapabilityResolver) do
      def initialize(grant)
        @grant = grant
      end

      def resolve(_context)
        @grant
      end
    end
  end

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

  def grant(capabilities:, workspace_id: context.workspace_id, principal: context.principal, credential: context.credential)
    Integration::Read::CapabilityGrant.new(
      workspace_id:,
      principal:,
      credential:,
      capabilities:
    )
  end

  def resolver_for(capability_grant)
    resolver_class.new(capability_grant)
  end

  def query(name, input: {})
    contract = Integration::Read::Contracts.fetch(name, 1)
    Integration::Read::Query.new(contract:, context:, input:)
  end

  it "declares stable capabilities on versioned read contracts" do
    expect(Integration::Read::Contracts.fetch("openings.search").required_capability).to eq("read:openings")
    expect(Integration::Read::Contracts.fetch("openings.get").required_capability).to eq("read:openings")
    expect(Integration::Read::Contracts.fetch("candidates.get").required_capability).to eq("read:candidates")
    expect(Integration::Read::Contracts.fetch("applications.get").required_capability).to eq("read:applications")
  end

  it "authorizes both opening reads with a read:openings grant" do
    authorization = described_class.new(
      capability_resolver: resolver_for(grant(capabilities: [ "read:openings" ]))
    )

    expect(authorization.authorize(query("openings.search"))).to be(true)
    expect(authorization.authorize(query("openings.get", input: { id: "opening_opaque" }))).to be(true)
  end

  it "denies a contract when its capability is not granted" do
    authorization = described_class.new(
      capability_resolver: resolver_for(grant(capabilities: [ "read:openings" ]))
    )

    expect do
      authorization.authorize(query("candidates.get", input: { id: "candidate_opaque" }))
    end.to raise_error(Integration::Read::Error::Unauthorized) { |error|
      expect(error.details).to eq(
        contract: "candidates.get.v1",
        required_capability: "read:candidates"
      )
    }
  end

  it "fails closed when a resolver returns a grant for another security identity" do
    mismatched_grant = grant(capabilities: [ "read:openings" ], principal: "user:someone-else")
    authorization = described_class.new(capability_resolver: resolver_for(mismatched_grant))

    expect do
      authorization.authorize(query("openings.search"))
    end.to raise_error(
      Integration::Read::Error::ContractViolation,
      "Capability grant identity does not match query context"
    )
  end

  it "does not accept caller supplied capability claims in query input" do
    authorization = described_class.new(
      capability_resolver: resolver_for(grant(capabilities: [ "read:openings" ]))
    )
    dispatcher = Integration::Read::Dispatcher.new(
      query_port: Integration::Read::Ports::Query.new,
      authorization_port: authorization
    )

    outcome = dispatcher.call(
      name: "candidates.get",
      version: 1,
      context:,
      input: { id: "candidate_opaque", capabilities: [ "read:candidates" ] }
    )

    expect(outcome.failure?).to be(true)
    expect(outcome.error.code).to eq("invalid_input")
  end
end
