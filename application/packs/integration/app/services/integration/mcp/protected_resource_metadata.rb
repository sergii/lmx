# frozen_string_literal: true

require "uri"

module Integration
  module Mcp
    class ProtectedResourceMetadata
      SCOPE_TOKEN = /\A[\x21\x23-\x5B\x5D-\x7E]+\z/

      attr_reader :resource, :authorization_servers, :scopes_supported, :resource_name

      def initialize(resource:, authorization_servers:, scopes_supported: [], resource_name: nil)
        @resource = resource_uri(resource)
        @authorization_servers = Array(authorization_servers).map { authorization_server_uri(_1) }.uniq.freeze
        raise ArgumentError, "authorization_servers must not be empty" if @authorization_servers.empty?

        @scopes_supported = Array(scopes_supported).map { scope_token(_1) }.uniq.sort.freeze
        @resource_name = optional_string(resource_name)
        freeze
      end

      def metadata_url
        path = resource.path.to_s
        suffix = path.empty? || path == "/" ? "" : path
        port = resource.port == 443 ? "" : ":#{resource.port}"

        "https://#{resource.host}#{port}/.well-known/oauth-protected-resource#{suffix}"
      end

      def to_h
        metadata = {
          "resource" => resource.to_s,
          "authorization_servers" => authorization_servers.map(&:to_s),
          "bearer_methods_supported" => [ "header" ]
        }
        metadata["scopes_supported"] = scopes_supported unless scopes_supported.empty?
        metadata["resource_name"] = resource_name if resource_name
        metadata.freeze
      end

      private

      def resource_uri(value)
        uri = https_uri(value, :resource)
        raise ArgumentError, "resource must not contain a query" if uri.query

        uri.freeze
      end

      def authorization_server_uri(value)
        uri = https_uri(value, :authorization_server)
        if uri.query
          raise ArgumentError, "authorization server issuer must not contain a query"
        end

        uri.freeze
      end

      def https_uri(value, field)
        raw = value.to_s.strip
        raise ArgumentError, "#{field} must be present" if raw.empty?

        uri = URI.parse(raw)
        unless uri.scheme&.downcase == "https" && uri.host && uri.userinfo.nil? && uri.fragment.nil?
          raise ArgumentError, "#{field} must be an absolute HTTPS URI without userinfo or fragment"
        end

        uri
      rescue URI::InvalidURIError
        raise ArgumentError, "#{field} must be a valid HTTPS URI"
      end

      def scope_token(value)
        token = value.to_s.strip
        unless SCOPE_TOKEN.match?(token)
          raise ArgumentError, "OAuth scopes must be non-empty RFC 6749 scope tokens"
        end

        token.freeze
      end

      def optional_string(value)
        string = value.to_s.strip
        string.empty? ? nil : string.freeze
      end
    end
  end
end
