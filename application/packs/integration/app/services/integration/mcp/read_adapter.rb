# frozen_string_literal: true

require "json"

module Integration
  module Mcp
    class ReadAdapter
      def initialize(dispatcher:)
        @dispatcher = dispatcher
      end

      def tools
        ReadTools.all
      end

      def call(name:, arguments:, context:)
        outcome = @dispatcher.call(
          name:,
          version: ReadTools.version_for(name),
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
