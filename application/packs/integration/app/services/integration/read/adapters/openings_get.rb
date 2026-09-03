# frozen_string_literal: true

module Integration
  module Read
    module Adapters
      class OpeningsGet < Ports::Query
        CONTRACT_IDENTIFIER = "openings.get.v1"
        PROVENANCE = { adapter: "market_catalog.public_api" }.freeze

        def initialize(opening_api:, workspace_scope:, not_found_errors: [])
          unless opening_api.respond_to?(:fetch_opening)
            raise Error::InvalidInput.new("opening_api must respond to fetch_opening")
          end
          unless workspace_scope.respond_to?(:call)
            raise Error::InvalidInput.new("workspace_scope must respond to call")
          end
          unless valid_not_found_errors?(not_found_errors)
            raise Error::InvalidInput.new("not_found_errors must contain StandardError subclasses")
          end

          @opening_api = opening_api
          @workspace_scope = workspace_scope
          @not_found_errors = not_found_errors.dup.freeze
          freeze
        end

        def call(query)
          ensure_contract!(query)

          data = @workspace_scope.call(query.context) do
            @opening_api.fetch_opening(opening_id: query.input.fetch(:id))
          end

          Ports::Result.new(data:, provenance: PROVENANCE)
        rescue StandardError => error
          raise unless not_found_error?(error)

          raise Error::NotFound.new(details: { contract: query.contract.identifier, id: query.input[:id] })
        end

        private

        def ensure_contract!(query)
          return if query.contract.identifier == CONTRACT_IDENTIFIER

          raise Error::Unsupported.new(
            "Opening query adapter does not support this contract",
            details: { contract: query.contract.identifier }
          )
        end

        def valid_not_found_errors?(errors)
          errors.is_a?(Array) && errors.all? do |error_class|
            error_class.is_a?(Class) && error_class < StandardError
          end
        end

        def not_found_error?(error)
          @not_found_errors.any? { |error_class| error.is_a?(error_class) }
        end
      end
    end
  end
end
