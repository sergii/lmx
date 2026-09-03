# frozen_string_literal: true

module Integration
  module Read
    module Adapters
      class OpeningsSearch < Ports::Query
        CONTRACT_IDENTIFIER = "openings.search.v1"
        PROVENANCE = { adapter: "market_catalog.public_api" }.freeze

        def initialize(opening_api:, workspace_scope:)
          unless opening_api.respond_to?(:search_openings)
            raise Error::InvalidInput.new("opening_api must respond to search_openings")
          end
          unless workspace_scope.respond_to?(:call)
            raise Error::InvalidInput.new("workspace_scope must respond to call")
          end

          @opening_api = opening_api
          @workspace_scope = workspace_scope
          freeze
        end

        def call(query)
          ensure_contract!(query)

          data = @workspace_scope.call(query.context) do
            @opening_api.search_openings(**query.input)
          end

          Ports::Result.new(data:, provenance: PROVENANCE)
        end

        private

        def ensure_contract!(query)
          return if query.contract.identifier == CONTRACT_IDENTIFIER

          raise Error::Unsupported.new(
            "Opening search adapter does not support this contract",
            details: { contract: query.contract.identifier }
          )
        end
      end
    end
  end
end
