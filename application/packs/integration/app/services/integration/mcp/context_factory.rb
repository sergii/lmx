# frozen_string_literal: true

module Integration
  module Mcp
    class ContextFactory
      def call(workspace_id:, principal:, credential:, actor:, executor:, client:, request_id: nil, correlation_id: nil)
        Read::Context.new(
          workspace_id:,
          principal:,
          credential:,
          actor:,
          executor:,
          interface: "mcp",
          client:,
          request_id:,
          correlation_id:
        )
      end
    end
  end
end
