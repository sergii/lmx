# frozen_string_literal: true

module Integration
  module Read
    class CredentialCapabilityResolver < Ports::CapabilityResolver
      SECURITY_ATTRIBUTES = CapabilityGrant::SECURITY_ATTRIBUTES.freeze

      def initialize(credential_source:)
        unless credential_source.respond_to?(:resolve)
          raise Error::InvalidInput.new("credential_source must respond to resolve")
        end

        @credential_source = credential_source
        freeze
      end

      def resolve(context)
        unless context.is_a?(Context)
          raise Error::InvalidInput.new("capability context must be Integration::Read::Context")
        end

        record = @credential_source.resolve(context)
        if record.nil?
          raise Error::Unauthenticated.new(
            "Credential is not recognized or active",
            details: { workspace_id: context.workspace_id, principal: context.principal }
          )
        end

        unless record.is_a?(Hash)
          raise Error::ContractViolation.new("credential source must return an object or nil")
        end

        grant = CapabilityGrant.new(
          workspace_id: fetch_attribute(record, :workspace_id),
          principal: fetch_attribute(record, :principal),
          credential: fetch_attribute(record, :credential),
          capabilities: fetch_attribute(record, :capabilities)
        )

        unless grant.matches?(context)
          raise Error::ContractViolation.new(
            "credential source returned a grant for a different security identity",
            details: { mismatched: mismatched_attributes(grant, context) }
          )
        end

        grant
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

      def mismatched_attributes(grant, context)
        SECURITY_ATTRIBUTES.reject do |attribute|
          grant.public_send(attribute) == context.public_send(attribute)
        end
      end
    end
  end
end
