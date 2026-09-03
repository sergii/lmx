# frozen_string_literal: true

module Integration
  module Read
    class Context
      ATTRIBUTES = %i[
        workspace_id principal credential actor executor interface client request_id correlation_id
      ].freeze

      attr_reader(*ATTRIBUTES)

      def initialize(
        workspace_id:,
        principal:,
        credential:,
        actor:,
        executor:,
        interface:,
        client:,
        request_id: nil,
        correlation_id: nil
      )
        @workspace_id = copy_string(workspace_id)
        @principal = copy_string(principal)
        @credential = copy_string(credential)
        @actor = copy_string(actor)
        @executor = copy_string(executor)
        @interface = copy_string(interface)
        @client = copy_string(client)
        @request_id = copy_string(request_id)
        @correlation_id = copy_string(correlation_id)
        freeze
      end

      def validate!
        unless present?(principal) && present?(credential)
          raise Error::Unauthenticated.new(details: { missing: missing_security_fields })
        end

        missing = %i[workspace_id actor executor interface client].reject { |attribute| present?(public_send(attribute)) }
        return self if missing.empty?

        raise Error::InvalidInput.new("Query context is incomplete", details: { missing: })
      end

      def to_h
        ATTRIBUTES.to_h { |attribute| [ attribute, public_send(attribute) ] }
      end

      # Credential references are retained internally for audit/provenance but are not echoed in response envelopes.
      def response_h
        to_h.reject { |key, _value| key == :credential }
      end

      private

      def copy_string(value)
        return if value.nil?

        value.to_s.dup.freeze
      end

      def present?(value)
        value.is_a?(String) && !value.strip.empty?
      end

      def missing_security_fields
        %i[principal credential].reject { |attribute| present?(public_send(attribute)) }
      end
    end
  end
end
