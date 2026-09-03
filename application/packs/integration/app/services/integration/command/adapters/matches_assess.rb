# frozen_string_literal: true

module Integration
  module Command
    module Adapters
      class MatchesAssess
        def initialize(match_api:, invalid_input_errors: [], not_found_errors: [], contract_violation_errors: [])
          unless match_api.respond_to?(:assess_match)
            raise Error::InvalidInput.new("match_api must respond to assess_match")
          end

          @match_api = match_api
          @invalid_input_errors = validate_errors(invalid_input_errors)
          @not_found_errors = validate_errors(not_found_errors)
          @contract_violation_errors = validate_errors(contract_violation_errors)
          freeze
        end

        def call(command)
          assessment = @match_api.assess_match(
            workspace_id: command.context.workspace_id,
            assessment: command.input,
            command: command.context.command_provenance
          )

          Ports::Result.new(
            data: assessment,
            provenance: { source: "intelligence.public_api", operation: "assess_match" }.freeze
          )
        rescue StandardError => error
          raise Error::InvalidInput.new(error.message) if matches?(@invalid_input_errors, error)
          raise Error::NotFound.new(error.message) if matches?(@not_found_errors, error)
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
