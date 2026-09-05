# frozen_string_literal: true

require "digest"
require "json"
require "uri"

module Integration
  module Mcp
    class OauthGrantStore
      class ConfigurationError < StandardError; end

      Entry = Data.define(
        :issuer,
        :subject,
        :client_id,
        :workspace_id,
        :principal,
        :credential,
        :actor,
        :executor,
        :client,
        :capabilities
      )

      def initialize(serialized:)
        @entries = parse(serialized).freeze
        raise ConfigurationError, "MCP OAuth grants must contain at least one entry" if entries.empty?

        duplicate_mapping = duplicate(entries.map { [ _1.issuer, _1.subject, _1.client_id ] })
        if duplicate_mapping
          raise ConfigurationError, "MCP OAuth issuer/subject/client mappings must be unique"
        end

        duplicate_credential = duplicate(entries.map(&:credential))
        if duplicate_credential
          raise ConfigurationError, "MCP OAuth credential references must be unique"
        end
      end

      def resolve(claims)
        entry = matching_entry(claims)
        return unless entry

        capabilities = entry.capabilities & claims.scopes
        return if capabilities.empty?

        RuntimeIdentity.new(
          workspace_id: entry.workspace_id,
          principal: entry.principal,
          credential: entry.credential,
          actor: entry.actor,
          executor: entry.executor,
          client: entry.client,
          capabilities:,
          runtime_id: runtime_id(entry)
        )
      end

      def known_identity?(claims)
        !matching_entry(claims).nil?
      end

      private

      attr_reader :entries

      def matching_entry(claims)
        entries.find do |candidate|
          candidate.issuer == claims.issuer &&
            candidate.subject == claims.subject &&
            candidate.client_id == claims.client_id
        end
      end

      def parse(serialized)
        unless serialized.is_a?(String)
          raise ConfigurationError, "MCP OAuth grants must be a JSON string"
        end

        raw = JSON.parse(serialized)
        unless raw.is_a?(Array)
          raise ConfigurationError, "MCP OAuth grants must be a JSON array"
        end

        raw.each_with_index.map { |attributes, index| build_entry(attributes, index:) }
      rescue JSON::ParserError => error
        raise ConfigurationError, "MCP OAuth grants JSON is invalid: #{error.message}"
      end

      def build_entry(attributes, index:)
        unless attributes.is_a?(Hash)
          raise ConfigurationError, "MCP OAuth grant entry #{index} must be an object"
        end

        principal = required_string(attributes, "principal", index:)
        subject = required_string(attributes, "subject", index:)
        token_client_id = required_string(attributes, "client_id", index:)

        Entry.new(
          issuer: issuer(attributes, index:),
          subject:,
          client_id: token_client_id,
          workspace_id: required_string(attributes, "workspace_id", index:),
          principal:,
          credential: required_string(attributes, "credential", index:),
          actor: optional_string(attributes, "actor", index:) || principal,
          executor: optional_string(attributes, "executor", index:) || "oauth:#{token_client_id}",
          client: optional_string(attributes, "client", index:) || token_client_id,
          capabilities: capabilities(attributes, index:)
        ).freeze
      end

      def issuer(attributes, index:)
        value = required_string(attributes, "issuer", index:)
        uri = URI.parse(value)
        unless uri.scheme&.downcase == "https" && uri.host && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
          raise ConfigurationError,
            "MCP OAuth grant entry #{index} issuer must be an absolute HTTPS issuer without query, userinfo, or fragment"
        end

        uri.to_s.freeze
      rescue URI::InvalidURIError
        raise ConfigurationError, "MCP OAuth grant entry #{index} issuer must be a valid HTTPS URI"
      end

      def capabilities(attributes, index:)
        values = attributes["capabilities"]
        unless values.is_a?(Array) && !values.empty?
          raise ConfigurationError, "MCP OAuth grant entry #{index} capabilities must be a non-empty array"
        end

        normalized = values.map do |value|
          unless value.is_a?(String) && !value.strip.empty?
            raise ConfigurationError,
              "MCP OAuth grant entry #{index} capabilities must contain non-empty strings"
          end

          value.strip
        end

        normalized.uniq.sort.freeze
      end

      def required_string(attributes, key, index:)
        value = optional_string(attributes, key, index:)
        return value if value

        raise ConfigurationError, "MCP OAuth grant entry #{index} #{key} must be present"
      end

      def optional_string(attributes, key, index:)
        value = attributes[key]
        return if value.nil?

        unless value.is_a?(String)
          raise ConfigurationError, "MCP OAuth grant entry #{index} #{key} must be a string"
        end

        stripped = value.strip
        stripped unless stripped.empty?
      end

      def duplicate(values)
        values.tally.find { |_value, count| count > 1 }&.first
      end

      def runtime_id(entry)
        fingerprint = Digest::SHA256.hexdigest(
          [ entry.issuer, entry.subject, entry.client_id, entry.credential ].join("\0")
        )
        "mcp-oauth:#{fingerprint}"
      end
    end
  end
end
