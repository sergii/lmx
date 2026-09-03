# frozen_string_literal: true

module Integration
  module Read
    module Adapters
      class CandidatesGet < Ports::Query
        CONTRACT_IDENTIFIER = "candidates.get.v1"
        PROVENANCE = { adapter: "talent_profile.public_api" }.freeze

        def initialize(candidate_api:, workspace_scope:, not_found_errors: [])
          unless candidate_api.respond_to?(:fetch_candidate)
            raise Error::InvalidInput.new("candidate_api must respond to fetch_candidate")
          end
          unless workspace_scope.respond_to?(:call)
            raise Error::InvalidInput.new("workspace_scope must respond to call")
          end
          unless valid_not_found_errors?(not_found_errors)
            raise Error::InvalidInput.new("not_found_errors must contain StandardError subclasses")
          end

          @candidate_api = candidate_api
          @workspace_scope = workspace_scope
          @not_found_errors = not_found_errors.dup.freeze
          freeze
        end

        def call(query)
          unless query.contract.identifier == CONTRACT_IDENTIFIER
            raise Error::Unsupported.new(
              "Candidate query adapter does not support this contract",
              details: { contract: query.contract.identifier }
            )
          end

          snapshot = @workspace_scope.call(query.context) do
            @candidate_api.fetch_candidate(candidate_id: query.input.fetch(:id))
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
