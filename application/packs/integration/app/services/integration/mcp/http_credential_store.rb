# frozen_string_literal: true

require "digest"
require "json"

module Integration
  module Mcp
    class HttpCredentialStore
      class ConfigurationError < StandardError; end

      Entry = Data.define(
        :token_sha256,
        :workspace_id,
        :principal,
        :credential,
        :actor,
        :executor,
        :client,
        :capabilities
      )

      TOKEN_DIGEST_PATTERN = /\A[0-9a-f]{64}\z/

      def initialize(serialized:)
        @entries = parse(serialized).freeze
        raise ConfigurationError, "MCP HTTP credentials must contain at least one entry" if entries.empty?

        duplicate_digest = duplicate(entries.map(&:token_sha256))
        if duplicate_digest
          raise ConfigurationError, "MCP HTTP credential token digests must be unique"
        end

        duplicate_credential = duplicate(entries.map(&:credential))
        if duplicate_credential
          raise ConfigurationError, "MCP HTTP credential references must be unique"
        end
      end

      def authenticate(token)
        return unless token.is_a?(String) && !token.empty?

        digest = Digest::SHA256.hexdigest(token)
        matched = nil

        entries.each do |entry|
          equal = ActiveSupport::SecurityUtils.secure_compare(entry.token_sha256, digest)
          matched = entry if equal
        end

        return unless matched

        RuntimeIdentity.new(
          workspace_id: matched.workspace_id,
          principal: matched.principal,
          credential: matched.credential,
          actor: matched.actor,
          executor: matched.executor,
          client: matched.client,
          capabilities: matched.capabilities,
          runtime_id: "mcp-http:#{matched.credential}"
        )
      end

      private

      attr_reader :entries

      def parse(serialized)
        unless serialized.is_a?(String)
          raise ConfigurationError, "MCP HTTP credentials must be a JSON string"
        end

        raw = JSON.parse(serialized)
        unless raw.is_a?(Array)
          raise ConfigurationError, "MCP HTTP credentials must be a JSON array"
        end

        raw.each_with_index.map { |attributes, index| build_entry(attributes, index:) }
      rescue JSON::ParserError => error
        raise ConfigurationError, "MCP HTTP credentials JSON is invalid: #{error.message}"
      end

      def build_entry(attributes, index:)
        unless attributes.is_a?(Hash)
          raise ConfigurationError, "MCP HTTP credential entry #{index} must be an object"
        end

        token_sha256 = required_string(attributes, "token_sha256", index:).downcase
        unless TOKEN_DIGEST_PATTERN.match?(token_sha256)
          raise ConfigurationError, "MCP HTTP credential entry #{index} token_sha256 must be a SHA-256 hex digest"
        end

        principal = required_string(attributes, "principal", index:)

        Entry.new(
          token_sha256:,
          workspace_id: required_string(attributes, "workspace_id", index:),
          principal:,
          credential: required_string(attributes, "credential", index:),
          actor: optional_string(attributes, "actor", index:) || principal,
          executor: optional_string(attributes, "executor", index:) || "mcp:http",
          client: optional_string(attributes, "client", index:) || "mcp-http",
          capabilities: capabilities(attributes, index:)
        ).freeze
      end

      def capabilities(attributes, index:)
        values = attributes["capabilities"]
        unless values.is_a?(Array) && !values.empty?
          raise ConfigurationError, "MCP HTTP credential entry #{index} capabilities must be a non-empty array"
        end

        normalized = values.map do |value|
          unless value.is_a?(String) && !value.strip.empty?
            raise ConfigurationError, "MCP HTTP credential entry #{index} capabilities must contain non-empty strings"
          end

          value.strip
        end

        normalized.uniq.sort.freeze
      end

      def required_string(attributes, key, index:)
        value = optional_string(attributes, key, index:)
        return value if value

        raise ConfigurationError, "MCP HTTP credential entry #{index} #{key} must be present"
      end

      def optional_string(attributes, key, index:)
        value = attributes[key]
        return if value.nil?

        unless value.is_a?(String)
          raise ConfigurationError, "MCP HTTP credential entry #{index} #{key} must be a string"
        end

        stripped = value.strip
        stripped unless stripped.empty?
      end

      def duplicate(values)
        values.tally.find { |_value, count| count > 1 }&.first
      end
    end
  end
end
