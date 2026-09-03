# frozen_string_literal: true

module Integration
  module Command
    class Error < StandardError
      attr_reader :code, :details

      def initialize(message = nil, code:, details: {})
        @code = code.to_s.freeze
        @details = details.dup.freeze
        super(message || code.to_s.tr("_", " "))
      end

      def to_h
        payload = { code:, message: message }
        payload[:details] = details unless details.empty?
        payload
      end

      class InvalidInput < Error
        def initialize(message = "Invalid input", details: {})
          super(message, code: :invalid_input, details:)
        end
      end

      class Unauthenticated < Error
        def initialize(message = "Authentication is required", details: {})
          super(message, code: :unauthenticated, details:)
        end
      end

      class Unauthorized < Error
        def initialize(message = "The principal is not authorized for this command", details: {})
          super(message, code: :unauthorized, details:)
        end
      end

      class NotFound < Error
        def initialize(message = "Resource not found", details: {})
          super(message, code: :not_found, details:)
        end
      end

      class IdempotencyConflict < Error
        def initialize(message = "Command identity conflicts with an existing command", details: {})
          super(message, code: :idempotency_conflict, details:)
        end
      end

      class ConcurrencyConflict < Error
        def initialize(message = "Command conflicts with a concurrent state change", details: {})
          super(message, code: :concurrency_conflict, details:)
        end
      end

      class Unsupported < Error
        def initialize(message = "Unsupported command contract", details: {})
          super(message, code: :unsupported, details:)
        end
      end

      class ContractViolation < Error
        def initialize(message = "Command adapter violated the command contract", details: {})
          super(message, code: :contract_violation, details:)
        end
      end
    end
  end
end
