# frozen_string_literal: true

require "json"

module Integration
  module Mcp
    class CommandAdapter
      def initialize(dispatcher:)
        @dispatcher = dispatcher
      end

      def tools
        CommandTools.all
      end

      def call(name:, arguments:, context:)
        outcome = @dispatcher.call(
          name:,
          version: CommandTools.version_for(name),
          context:,
          input: arguments || {}
        )
        payload = outcome.to_h

        {
          content: [ { type: "text", text: JSON.generate(payload) } ],
          structuredContent: payload,
          isError: outcome.failure?
        }
      end
    end
  end
end
