# frozen_string_literal: true

module Integration
  module Read
    class Dispatcher
      def initialize(query_port:, authorization_port:)
        @query_port = query_port
        @authorization_port = authorization_port
      end

      def call(name:, version: 1, context:, input: {})
        contract = Contracts.fetch(name, version)
        query = Query.new(contract:, context:, input:)

        authorized = @authorization_port.authorize(query)
        raise Error::Unauthorized unless authorized

        port_result = @query_port.call(query)
        unless port_result.is_a?(Ports::Result)
          raise Error::ContractViolation.new(
            "Query port must return Integration::Read::Ports::Result",
            details: { contract: contract.identifier }
          )
        end

        data = contract.normalize_output(port_result.data)
        Outcome.success(contract: contract.reference, context:, data:, provenance: port_result.provenance)
      rescue Error => error
        Outcome.failure(
          contract: contract_reference(name, version, defined?(contract) ? contract : nil),
          context: context.is_a?(Context) ? context : nil,
          error:
        )
      end

      private

      def contract_reference(name, version, contract)
        return contract.reference if contract

        { name: name.to_s, version: version }
      end
    end
  end
end
