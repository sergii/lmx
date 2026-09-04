# frozen_string_literal: true

require "digest"

module Integration
  module Mcp
    class RuntimeIdentity
      ATTRIBUTES = %i[
        workspace_id principal credential actor executor client capabilities
      ].freeze

      attr_reader(*ATTRIBUTES)

      def initialize(workspace_id:, principal:, credential:, actor:, executor:, client:, capabilities:)
        @workspace_id = required_string(workspace_id, :workspace_id)
        @principal = required_string(principal, :principal)
        @credential = required_string(credential, :credential)
        @actor = required_string(actor, :actor)
        @executor = required_string(executor, :executor)
        @client = required_string(client, :client)
        @capabilities = normalize_capabilities(capabilities)
        freeze
      end

      def credential_source
        identity = self
        Object.new.tap do |source|
          source.define_singleton_method(:resolve) do |context|
            next unless context.workspace_id == identity.workspace_id
            next unless context.principal == identity.principal
            next unless context.credential == identity.credential

            {
              workspace_id: identity.workspace_id,
              principal: identity.principal,
              credential: identity.credential,
              capabilities: identity.capabilities
            }.freeze
          end
        end
      end

      def read_context(request_id:, correlation_id: nil)
        Read::Context.new(
          workspace_id:,
          principal:,
          credential:,
          actor:,
          executor:,
          interface: "mcp",
          client:,
          request_id: request_id.to_s,
          correlation_id:
        )
      end

      def command_context(request_id:, tool_name:, correlation_id: nil)
        fingerprint = command_fingerprint(request_id:, tool_name:)

        Command::Context.new(
          workspace_id:,
          principal:,
          credential:,
          actor:,
          executor:,
          interface: "mcp",
          client:,
          request_id: request_id.to_s,
          correlation_id:,
          causation_id: request_id.to_s,
          message_id: "mcp-message:#{fingerprint}",
          command_id: "mcp-command:#{fingerprint}",
          idempotency_key: "mcp-idempotency:#{fingerprint}"
        )
      end

      private

      def required_string(value, field)
        string = value.to_s.strip
        raise ArgumentError, "#{field} must be present" if string.empty?

        string.freeze
      end

      def normalize_capabilities(values)
        unless values.is_a?(Array)
          raise ArgumentError, "capabilities must be an array"
        end

        normalized = values.map { required_string(_1, :capability) }.uniq.sort
        raise ArgumentError, "capabilities must not be empty" if normalized.empty?

        normalized.freeze
      end

      def command_fingerprint(request_id:, tool_name:)
        request = required_string(request_id, :request_id)
        tool = required_string(tool_name, :tool_name)

        Digest::SHA256.hexdigest(
          [ workspace_id, principal, credential, client, request, tool ].join("\0")
        )
      end
    end
  end
end
