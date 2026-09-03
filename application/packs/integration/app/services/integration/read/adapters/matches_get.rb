# frozen_string_literal: true

module Integration
  module Read
    module Adapters
      class MatchesGet < Ports::Query
        CONTRACT_IDENTIFIER = "matches.get.v1"
        PROVENANCE = { adapter: "intelligence.public_api" }.freeze

        def initialize(match_api:, workspace_scope:, not_found_errors: [])
          unless match_api.respond_to?(:fetch_match_assessment)
            raise Error::InvalidInput.new("match_api must respond to fetch_match_assessment")
          end
          unless workspace_scope.respond_to?(:call)
            raise Error::InvalidInput.new("workspace_scope must respond to call")
          end
          unless valid_not_found_errors?(not_found_errors)
            raise Error::InvalidInput.new("not_found_errors must contain StandardError subclasses")
          end

          @match_api = match_api
          @workspace_scope = workspace_scope
          @not_found_errors = not_found_errors.dup.freeze
          freeze
        end

        def call(query)
          unless query.contract.identifier == CONTRACT_IDENTIFIER
            raise Error::Unsupported.new(
              "Match query adapter does not support this contract",
              details: { contract: query.contract.identifier }
            )
          end

          snapshot = @workspace_scope.call(query.context) do
            @match_api.fetch_match_assessment(
              workspace_id: query.context.workspace_id,
              assessment_id: query.input.fetch(:id)
            )
          end

          Ports::Result.new(data: snapshot, provenance: PROVENANCE)
        rescue StandardError => error
          raise unless not_found_error?(error)

          raise Error::NotFound.new(
            details: {
              contract: query.contract.identifier,
              id: query.input[:id]
            }
          )
        end

        private

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
