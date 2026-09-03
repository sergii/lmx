# frozen_string_literal: true

module Integration
  module Command
    class Context
      ATTRIBUTES = %i[
        workspace_id principal credential actor executor interface client request_id correlation_id causation_id
        message_id command_id idempotency_key
      ].freeze
      REQUIRED = %i[
        workspace_id principal credential actor executor interface client message_id command_id idempotency_key
      ].freeze

      attr_reader(*ATTRIBUTES)

      def initialize(**attributes)
        ATTRIBUTES.each do |attribute|
          instance_variable_set("@#{attribute}", copy_string(attributes[attribute]))
        end
        freeze
      end

      def validate!
        missing_security = %i[principal credential].reject { |attribute| present?(public_send(attribute)) }
        unless missing_security.empty?
          raise Error::Unauthenticated.new(details: { missing: missing_security })
        end

        missing = REQUIRED.reject { |attribute| present?(public_send(attribute)) }
        return self if missing.empty?

        raise Error::InvalidInput.new("Command context is incomplete", details: { missing: })
      end

      def to_h
        ATTRIBUTES.to_h { |attribute| [ attribute, public_send(attribute) ] }
      end

      def response_h
        to_h.reject { |key, _value| key == :credential }
      end

      def command_provenance
        {
          command_id:,
          idempotency_key:,
          principal:,
          credential:,
          actor:,
          executor:,
          interface:,
          client:,
          correlation_id:,
          causation_id:
        }.freeze
      end

      private

      def copy_string(value)
        return if value.nil?

        value.to_s.dup.freeze
      end

      def present?(value)
        value.is_a?(String) && !value.strip.empty?
      end
    end
  end
end
