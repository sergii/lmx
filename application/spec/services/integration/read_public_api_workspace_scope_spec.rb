# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration::Read::Adapters::PublicApiWorkspaceScope do
  let(:context) do
    Integration::Read::Context.new(
      workspace_id: "org_opaque",
      principal: "user:serhii",
      credential: "credential_opaque",
      actor: "human:serhii",
      executor: "agent:generic",
      interface: "mcp",
      client: "generic-client"
    )
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

  it "passes the opaque workspace ID to the public Workspace API and returns the block result" do
    scope = described_class.new(workspace_api:)

    result = scope.call(context) { :scoped_result }

    expect(result).to eq(:scoped_result)
    expect(workspace_api.workspace_ids).to eq([ "org_opaque" ])
  end

  it "maps configured public Workspace lookup failures to the stable Integration not-found error" do
    workspace_not_found = Class.new(StandardError)
    failing_api = Class.new do
      define_method(:initialize) { |error_class| @error_class = error_class }
      define_method(:with_workspace) do |workspace_id:|
        raise @error_class, workspace_id
      end
    end.new(workspace_not_found)
    scope = described_class.new(workspace_api: failing_api, not_found_errors: [ workspace_not_found ])

    expect { scope.call(context) { :unreachable } }
      .to raise_error(Integration::Read::Error::NotFound) do |error|
        expect(error.code).to eq("not_found")
        expect(error.details).to eq(workspace_id: "org_opaque")
      end
  end

  it "does not swallow unconfigured failures from the Workspace API or the caller block" do
    scope = described_class.new(workspace_api:)

    expect { scope.call(context) { raise "domain failure" } }
      .to raise_error(RuntimeError, "domain failure")
  end

  it "fails fast for an invalid adapter dependency or workspace context" do
    expect { described_class.new(workspace_api: Object.new) }
      .to raise_error(Integration::Read::Error::InvalidInput, /with_workspace/)

    scope = described_class.new(workspace_api:)
    invalid_context = Struct.new(:workspace_id).new("")

    expect { scope.call(invalid_context) { :unreachable } }
      .to raise_error(Integration::Read::Error::InvalidInput, "workspace_id is required")
    expect { scope.call(context) }
      .to raise_error(Integration::Read::Error::InvalidInput, "workspace scope block is required")
  end
end
