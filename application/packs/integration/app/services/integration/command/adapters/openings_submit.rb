# frozen_string_literal: true

module Integration
  module Command
    module Adapters
      class OpeningsSubmit
        def initialize(market_api:, invalid_input_errors: [], contract_violation_errors: [])
          unless market_api.respond_to?(:submit_opening)
            raise Error::InvalidInput.new("market_api must respond to submit_opening")
          end

          @market_api = market_api
          @invalid_input_errors = validate_errors(invalid_input_errors)
          @contract_violation_errors = validate_errors(contract_violation_errors)
          freeze
        end

        def call(command)
          submission = @market_api.submit_opening(
            workspace_id: command.context.workspace_id,
            **command.input,
            command: command.context.command_provenance,
            ingress_interface: command.context.interface
          )

          Ports::Result.new(
            data: submission,
            provenance: { source: "market_catalog.public_api", operation: "submit_opening" }.freeze
          )
        rescue StandardError => error
          raise Error::InvalidInput.new(error.message) if matches?(@invalid_input_errors, error)
          raise Error::ContractViolation.new(error.message) if matches?(@contract_violation_errors, error)

          raise
        end

        private

        def validate_errors(errors)
          unless errors.is_a?(Array) && errors.all? { |error_class| error_class.is_a?(Class) && error_class < StandardError }
            raise Error::InvalidInput.new("error mappings must contain StandardError subclasses")
          end

          errors.dup.freeze
        end

        def matches?(classes, error)
          classes.any? { |error_class| error.is_a?(error_class) }
        end
      end
    end
  end
end
