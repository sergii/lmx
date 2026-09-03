# frozen_string_literal: true

module Integration
  module Read
    module Adapters
      class ApplicationsGet < Ports::Query
        CONTRACT_IDENTIFIER = "applications.get.v1"
        PROVENANCE = { adapter: "personal_crm.public_api" }.freeze

        def initialize(application_api:, workspace_scope:, not_found_errors: [])
          unless application_api.respond_to?(:fetch_application)
            raise Error::InvalidInput.new("application_api must respond to fetch_application")
          end
          unless workspace_scope.respond_to?(:call)
            raise Error::InvalidInput.new("workspace_scope must respond to call")
          end
          unless valid_not_found_errors?(not_found_errors)
            raise Error::InvalidInput.new("not_found_errors must contain StandardError subclasses")
          end

          @application_api = application_api
          @workspace_scope = workspace_scope
          @not_found_errors = not_found_errors.dup.freeze
          freeze
        end

        def call(query)
          ensure_contract!(query)

          data = @workspace_scope.call(query.context) do
            @application_api.fetch_application(application_id: query.input.fetch(:id))
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
            "Application query adapter does not support this contract",
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
