# frozen_string_literal: true

module Integration
  module Command
    class Command
      attr_reader :contract, :context, :input

      def initialize(contract:, context:, input:)
        unless contract.is_a?(Contract)
          raise Error::InvalidInput.new("command contract is invalid")
        end
        unless context.is_a?(Context)
          raise Error::InvalidInput.new("command context must be Integration::Command::Context")
        end

        @contract = contract
        @context = context.validate!
        @input = contract.normalize_input(input)
        freeze
      end
    end
  end
end
