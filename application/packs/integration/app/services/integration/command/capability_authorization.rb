# frozen_string_literal: true

module Integration
  module Command
    class CapabilityAuthorization
      SECURITY_ATTRIBUTES = %i[workspace_id principal credential].freeze

      def initialize(credential_source:)
        unless credential_source.respond_to?(:resolve)
          raise Error::InvalidInput.new("credential_source must respond to resolve")
        end

        @credential_source = credential_source
        freeze
      end

      def authorize(command)
        unless command.is_a?(Command)
          raise Error::InvalidInput.new("authorization requires Integration::Command::Command")
        end

        record = @credential_source.resolve(command.context)
        if record.nil?
          raise Error::Unauthenticated.new(
            "Credential is not recognized or active",
            details: { workspace_id: command.context.workspace_id, principal: command.context.principal }
          )
        end
        unless record.is_a?(Hash)
          raise Error::ContractViolation.new("credential source must return an object or nil")
        end

        mismatched = SECURITY_ATTRIBUTES.reject do |attribute|
          fetch_attribute(record, attribute).to_s == command.context.public_send(attribute)
        end
        unless mismatched.empty?
          raise Error::ContractViolation.new(
            "credential source returned a grant for a different security identity",
            details: { mismatched: }
          )
        end

        capabilities = fetch_attribute(record, :capabilities)
        unless capabilities.is_a?(Array) && capabilities.all? { |value| value.is_a?(String) || value.is_a?(Symbol) }
          raise Error::ContractViolation.new("capabilities must be an array of strings")
        end

        required = command.contract.required_capability
        return true if capabilities.map(&:to_s).include?(required)

        raise Error::Unauthorized.new(
          details: { contract: command.contract.identifier, required_capability: required }
        )
      rescue KeyError => error
        raise Error::ContractViolation.new(
          "credential source result is incomplete",
          details: { missing: error.key }
        )
      end

      private

      def fetch_attribute(record, attribute)
        return record.fetch(attribute) if record.key?(attribute)

        record.fetch(attribute.to_s)
      end
    end
  end
end
