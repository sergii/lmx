# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::Mcp::HttpCredentialStore do
  let(:token) { "test-secret-token-with-high-entropy" }
  let(:serialized) do
    JSON.generate(
      [
        {
          token_sha256: Digest::SHA256.hexdigest(token),
          workspace_id: "org_01example",
          principal: "user:serhii",
          credential: "mcp-http:chatgpt",
          actor: "human:serhii",
          executor: "agent:chatgpt",
          client: "chatgpt",
          capabilities: %w[read:openings submit:openings read:openings]
        }
      ]
    )
  end

  it "authenticates a bearer secret against its digest and builds trusted runtime identity" do
    identity = described_class.new(serialized:).authenticate(token)

    expect(identity).to be_a(Integration::Mcp::RuntimeIdentity)
    expect(identity.workspace_id).to eq("org_01example")
    expect(identity.principal).to eq("user:serhii")
    expect(identity.credential).to eq("mcp-http:chatgpt")
    expect(identity.client).to eq("chatgpt")
    expect(identity.capabilities).to eq(%w[read:openings submit:openings])
    expect(identity.runtime_id).to eq("mcp-http:mcp-http:chatgpt")
  end

  it "does not authenticate an unknown bearer secret" do
    identity = described_class.new(serialized:).authenticate("wrong-token")

    expect(identity).to be_nil
  end

  it "rejects malformed token digests before serving requests" do
    malformed = JSON.generate(
      [
        {
          token_sha256: "not-a-digest",
          workspace_id: "org_01example",
          principal: "user:serhii",
          credential: "mcp-http:test",
          capabilities: [ "read:openings" ]
        }
      ]
    )

    expect { described_class.new(serialized: malformed) }
      .to raise_error(described_class::ConfigurationError, /SHA-256 hex digest/)
  end

  it "rejects duplicate credential references" do
    attributes = {
      workspace_id: "org_01example",
      principal: "user:serhii",
      credential: "mcp-http:duplicate",
      capabilities: [ "read:openings" ]
    }
    duplicated = JSON.generate(
      [
        attributes.merge(token_sha256: Digest::SHA256.hexdigest("first-token")),
        attributes.merge(token_sha256: Digest::SHA256.hexdigest("second-token"))
      ]
    )

    expect { described_class.new(serialized: duplicated) }
      .to raise_error(described_class::ConfigurationError, /references must be unique/)
  end
end
