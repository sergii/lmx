# frozen_string_literal: true

module Integration
  module Read
    class QueryRouter < Ports::Query
      def initialize(routes:)
        unless routes.is_a?(Hash)
          raise Error::InvalidInput.new("query routes must be an object")
        end

        @routes = routes.each_with_object({}) do |(identifier, handler), normalized|
          unless handler.respond_to?(:call)
            raise Error::InvalidInput.new(
              "query route handler must respond to call",
              details: { contract: identifier.to_s }
            )
          end

          normalized[identifier.to_s] = handler
        end.freeze
        freeze
      end

      def call(query)
        handler = @routes[query.contract.identifier]
        unless handler
          raise Error::NotImplemented.new(
            "No query implementation is registered",
            details: { contract: query.contract.identifier }
          )
        end

        handler.call(query)
      end

      def registered?(contract)
        identifier = contract.respond_to?(:identifier) ? contract.identifier : contract.to_s
        @routes.key?(identifier)
      end
    end
  end
end
