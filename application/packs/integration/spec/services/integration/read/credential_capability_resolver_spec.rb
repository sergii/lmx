# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::Read::CredentialCapabilityResolver do
  let(:context) do
    Integration::Read::Context.new(
      workspace_id: "org_opaque",
      principal: "user:serhii",
      credential: "credential_opaque",
      actor: "human:serhii",
      executor: "agent:chatgpt",
      interface: "mcp",
      client: "chatgpt"
    )
  end

  let(:record) do
    {
      workspace_id: context.workspace_id,
      principal: context.principal,
      credential: context.credential,
      capabilities: [ "read:candidates", "read:openings" ]
    }
  end

  let(:credential_source) do
    source_record = record

    Class.new do
      attr_reader :contexts

      define_method(:initialize) do
        @contexts = []
      end

      define_method(:resolve) do |resolved_context|
        @contexts << resolved_context
        source_record
      end
    end.new
  end

  subject(:resolver) { described_class.new(credential_source:) }

  it "builds an identity-bound capability grant from the server-side credential source" do
    grant = resolver.resolve(context)

    expect(grant).to be_a(Integration::Read::CapabilityGrant)
    expect(grant.workspace_id).to eq(context.workspace_id)
    expect(grant.principal).to eq(context.principal)
    expect(grant.credential).to eq(context.credential)
    expect(grant.capabilities).to eq([ "read:candidates", "read:openings" ])
    expect(credential_source.contexts).to eq([ context ])
  end

  context "when the credential is unknown or inactive" do
    let(:record) { nil }

    it "fails closed as unauthenticated" do
      expect { resolver.resolve(context) }
        .to raise_error(Integration::Read::Error::Unauthenticated, "Credential is not recognized or active")
    end
  end

  context "when the source returns a different security identity" do
    let(:record) do
      {
        workspace_id: "org_other",
        principal: context.principal,
        credential: context.credential,
        capabilities: [ "read:candidates" ]
      }
    end

    it "rejects the source result instead of re-binding it to the request" do
      expect { resolver.resolve(context) }
        .to raise_error(Integration::Read::Error::ContractViolation) { |error|
          expect(error.details).to eq(mismatched: [ :workspace_id ])
        }
    end
  end

  context "when the source result is incomplete" do
    let(:record) do
      {
        workspace_id: context.workspace_id,
        principal: context.principal,
        credential: context.credential
      }
    end

    it "raises a contract violation" do
      expect { resolver.resolve(context) }
        .to raise_error(Integration::Read::Error::ContractViolation) { |error|
          expect(error.details).to eq(missing: "capabilities")
        }
    end
  end

  context "when the source violates its return contract" do
    let(:record) { [ "read:candidates" ] }

    it "raises a contract violation" do
      expect { resolver.resolve(context) }
        .to raise_error(Integration::Read::Error::ContractViolation, "credential source must return an object or nil")
    end
  end

  it "rejects an invalid credential source at composition time" do
    expect { described_class.new(credential_source: Object.new) }
      .to raise_error(Integration::Read::Error::InvalidInput, "credential_source must respond to resolve")
  end
end
