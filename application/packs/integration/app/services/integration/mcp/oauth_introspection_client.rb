# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "uri"

module Integration
  module Mcp
    class OauthIntrospectionClient
      class ConfigurationError < StandardError; end
      class Unavailable < StandardError; end

      Claims = Data.define(
        :issuer,
        :subject,
        :client_id,
        :scopes,
        :audiences,
        :expires_at
      )

      DEFAULT_OPEN_TIMEOUT = 2
      DEFAULT_READ_TIMEOUT = 3

      def initialize(
        endpoint:,
        issuer:,
        resource:,
        client_id:,
        client_secret:,
        requester: nil,
        clock: -> { Time.now },
        open_timeout: DEFAULT_OPEN_TIMEOUT,
        read_timeout: DEFAULT_READ_TIMEOUT
      )
        @endpoint = https_uri(endpoint, :introspection_endpoint)
        @issuer = https_identifier(issuer, :issuer)
        @resource = https_identifier(resource, :resource)
        @client_id = required_string(client_id, :client_id)
        @client_secret = required_string(client_secret, :client_secret)
        @requester = requester || method(:perform_request)
        @clock = clock
        @open_timeout = positive_timeout(open_timeout, :open_timeout)
        @read_timeout = positive_timeout(read_timeout, :read_timeout)
      end

      def verify(token)
        raw_token = required_string(token, :token)
        status, body = requester.call(raw_token)
        unless status.to_i == 200
          raise Unavailable, "OAuth token introspection returned HTTP #{status}"
        end

        payload = JSON.parse(body.to_s)
        unless payload.is_a?(Hash)
          raise Unavailable, "OAuth token introspection response must be a JSON object"
        end

        return unless payload["active"] == true
        return unless issuer_matches?(payload)

        subject = claim_string(payload["sub"])
        token_client_id = claim_string(payload["client_id"])
        scopes = scope_list(payload["scope"])
        audiences = audience_list(payload["aud"])
        expires_at = expiration(payload["exp"])

        return unless subject && token_client_id
        return if scopes.empty?
        return unless audiences.include?(resource)
        return if payload.key?("exp") && expires_at.nil?
        return if expires_at && expires_at <= clock.call

        Claims.new(
          issuer:,
          subject:,
          client_id: token_client_id,
          scopes: scopes.freeze,
          audiences: audiences.freeze,
          expires_at:
        ).freeze
      rescue JSON::ParserError => error
        raise Unavailable, "OAuth token introspection returned invalid JSON: #{error.message}"
      rescue Timeout::Error, SocketError, EOFError, IOError, SystemCallError, OpenSSL::SSL::SSLError => error
        raise Unavailable, "OAuth token introspection request failed: #{error.class}"
      end

      private

      attr_reader :endpoint, :issuer, :resource, :client_id, :client_secret, :requester, :clock,
        :open_timeout, :read_timeout

      def perform_request(token)
        request = Net::HTTP::Post.new(endpoint.request_uri)
        request.basic_auth(client_id, client_secret)
        request["Accept"] = "application/json"
        request["Content-Type"] = "application/x-www-form-urlencoded"
        request.body = URI.encode_www_form(token:, token_type_hint: "access_token")

        http = Net::HTTP.new(endpoint.host, endpoint.port)
        http.use_ssl = true
        http.open_timeout = open_timeout
        http.read_timeout = read_timeout

        response = http.request(request)
        [ response.code.to_i, response.body.to_s ]
      end

      def issuer_matches?(payload)
        return true unless payload.key?("iss")

        claim_string(payload["iss"]) == issuer
      end

      def scope_list(value)
        return [] unless value.is_a?(String)

        value.split(" ").map(&:strip).reject(&:empty?).uniq.sort
      end

      def audience_list(value)
        values = value.is_a?(Array) ? value : [ value ]
        values.filter_map { claim_string(_1) }.uniq.sort
      end

      def expiration(value)
        return if value.nil?
        return unless value.is_a?(Numeric)

        Time.at(value.to_f)
      rescue RangeError
        nil
      end

      def claim_string(value)
        return unless value.is_a?(String)

        string = value.strip
        string unless string.empty?
      end

      def https_uri(value, field)
        uri = URI.parse(required_string(value, field))
        unless uri.scheme&.downcase == "https" && uri.host && uri.userinfo.nil? && uri.fragment.nil?
          raise ConfigurationError, "#{field} must be an absolute HTTPS URI without userinfo or fragment"
        end

        uri.freeze
      rescue URI::InvalidURIError
        raise ConfigurationError, "#{field} must be a valid HTTPS URI"
      end

      def https_identifier(value, field)
        uri = https_uri(value, field)
        raise ConfigurationError, "#{field} must not contain a query" if uri.query

        uri.to_s.freeze
      end

      def required_string(value, field)
        string = value.to_s.strip
        raise ConfigurationError, "#{field} must be present" if string.empty?

        string.freeze
      end

      def positive_timeout(value, field)
        number = Float(value)
        raise ConfigurationError, "#{field} must be positive" unless number.positive?

        number
      rescue ArgumentError, TypeError
        raise ConfigurationError, "#{field} must be a positive number"
      end
    end
  end
end
