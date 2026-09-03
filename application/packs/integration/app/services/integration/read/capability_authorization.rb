# frozen_string_literal: true

module Integration
  module Read
    class CapabilityAuthorization < Ports::Authorization
      def initialize(capability_resolver:)
        unless capability_resolver.respond_to?(:resolve)
          raise Error::InvalidInput.new("capability_resolver must respond to resolve")
        end

        @capability_resolver = capability_resolver
        freeze
      end

      def authorize(query)
        grant = @capability_resolver.resolve(query.context)
        unless grant.is_a?(CapabilityGrant)
          raise Error::ContractViolation.new(
            "Capability resolver must return Integration::Read::CapabilityGrant",
            details: { contract: query.contract.identifier }
          )
        end

        unless grant.matches?(query.context)
          raise Error::ContractViolation.new(
            "Capability grant identity does not match query context",
            details: { contract: query.contract.identifier }
          )
        end

        required_capability = query.contract.required_capability
        return true if grant.allows?(required_capability)

        raise Error::Unauthorized.new(
          "The principal is not authorized for this query",
          details: {
            contract: query.contract.identifier,
            required_capability:
          }
        )
      end
    end
  end
end
