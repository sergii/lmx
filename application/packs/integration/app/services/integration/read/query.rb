# frozen_string_literal: true

module Integration
  module Read
    class Query
      attr_reader :contract, :context, :input

      def initialize(contract:, context:, input: {})
        unless contract.is_a?(Contract)
          raise Error::InvalidInput.new("contract must be an Integration read contract")
        end
        unless context.is_a?(Context)
          raise Error::InvalidInput.new("context must be an Integration read context")
        end

        context.validate!
        @contract = contract
        @context = context
        @input = contract.normalize_input(input)
        freeze
      end

      def to_h
        {
          contract: contract.reference,
          context: context.to_h,
          input:
        }
      end
    end
  end
end
