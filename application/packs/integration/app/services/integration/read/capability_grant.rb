# frozen_string_literal: true

module Integration
  module Read
    class CapabilityGrant
      SECURITY_ATTRIBUTES = %i[workspace_id principal credential].freeze

      attr_reader :workspace_id, :principal, :credential, :capabilities

      def initialize(workspace_id:, principal:, credential:, capabilities:)
        @workspace_id = copy_string(workspace_id)
        @principal = copy_string(principal)
        @credential = copy_string(credential)
        @capabilities = normalize_capabilities(capabilities)
        validate!
        freeze
      end

      def allows?(capability)
        capabilities.include?(capability.to_s)
      end

      def matches?(context)
        return false unless context.is_a?(Context)

        SECURITY_ATTRIBUTES.all? do |attribute|
          public_send(attribute) == context.public_send(attribute)
        end
      end

      private

      def normalize_capabilities(value)
        unless value.is_a?(Array)
          raise Error::ContractViolation.new("capabilities must be an array")
        end

        normalized = value.map do |capability|
          unless capability.is_a?(String) || capability.is_a?(Symbol)
            raise Error::ContractViolation.new("capability values must be strings")
          end

          capability.to_s.dup.freeze
        end

        if normalized.any? { |capability| capability.strip.empty? }
          raise Error::ContractViolation.new("capability values must be non-empty strings")
        end

        normalized.uniq.freeze
      end

      def validate!
        missing = SECURITY_ATTRIBUTES.reject do |attribute|
          value = public_send(attribute)
          value.is_a?(String) && !value.strip.empty?
        end
        return if missing.empty?

        raise Error::ContractViolation.new("Capability grant identity is incomplete", details: { missing: })
      end

      def copy_string(value)
        return if value.nil?

        value.to_s.dup.freeze
      end
    end
  end
end
