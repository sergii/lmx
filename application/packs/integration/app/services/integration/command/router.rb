# frozen_string_literal: true

module Integration
  module Command
    class Router
      def initialize(routes:)
        unless routes.is_a?(Hash)
          raise Error::InvalidInput.new("command routes must be an object")
        end

        @routes = routes.transform_keys(&:to_s).freeze
        freeze
      end

      def call(command)
        handler = @routes[command.contract.identifier]
        unless handler&.respond_to?(:call)
          raise Error::Unsupported.new(
            "Command contract is not implemented",
            details: { contract: command.contract.identifier }
          )
        end

        handler.call(command)
      end
    end
  end
end
