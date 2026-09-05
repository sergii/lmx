# frozen_string_literal: true

require "active_support/key_generator"
require "active_support/message_encryptor"
require "digest"
require "json"
require "uri"

module Integration
  module McpOauthPairing
    class Error < StandardError; end
    class InvalidTicket < Error; end
    class InvalidInput < Error; end
    class Conflict < Error; end
    class NotFound < Error; end
    class Unauthorized < Error; end

    Ticket = Data.define(
      :issuer,
      :subject,
      :client_id,
      :scopes,
      :resource,
      :issued_at,
      :expires_at
    )
    IssuedTicket = Data.define(:token, :expires_at)

    VERSION = 1
    PURPOSE = "integration/mcp/oauth-pairing"
    MAX_TTL = 15.minutes
    PAIRING_PATH = "/settings/agent-access/pair"

    module_function

    def issue(claims:, resource:, encryptor: default_encryptor, clock: -> { Time.current })
      now = clock.call
      expires_at = pairing_expiration(claims.expires_at, now:)
      raise InvalidInput, "OAuth token is too close to expiry for pairing" unless expires_at > now
      raise InvalidInput, "OAuth token has no pairable MCP scopes" if pairable_capabilities(claims.scopes).empty?

      payload = {
        "v" => VERSION,
        "issuer" => required_string(claims.issuer, :issuer),
        "subject" => required_string(claims.subject, :subject),
        "client_id" => required_string(claims.client_id, :client_id),
        "scopes" => normalize_capabilities(claims.scopes),
        "resource" => normalize_resource(resource),
        "issued_at" => now.iso8601(6),
        "expires_at" => expires_at.iso8601(6)
      }

      token = encryptor.encrypt_and_sign(
        payload,
        expires_in: expires_at - now,
        purpose: PURPOSE
      )
      IssuedTicket.new(token:, expires_at:).freeze
    end

    def describe(token:, resource:, encryptor: default_encryptor, clock: -> { Time.current })
      raw = required_string(token, :pairing_token)
      payload = encryptor.decrypt_and_verify(raw, purpose: PURPOSE)
      ticket = build_ticket(payload)

      raise InvalidTicket, "pairing ticket is for a different MCP resource" unless ticket.resource == normalize_resource(resource)
      raise InvalidTicket, "pairing ticket has expired" unless ticket.expires_at > clock.call

      ticket
    rescue ActiveSupport::MessageEncryptor::InvalidMessage,
      JSON::ParserError,
      TypeError,
      ArgumentError => error
      raise InvalidTicket, "pairing ticket is invalid or expired: #{error.message}"
    end

    def approve(
      token:,
      resource:,
      workspace_id:,
      membership_id:,
      capabilities:,
      managed_by_membership_id:,
      grant_registry: McpOauthGrantRegistry,
      encryptor: default_encryptor,
      clock: -> { Time.current }
    )
      ticket = describe(token:, resource:, encryptor:, clock:)
      normalized = normalize_capabilities(capabilities)
      raise InvalidInput, "select at least one MCP capability" if normalized.empty?

      extra = normalized - pairable_capabilities(ticket.scopes)
      unless extra.empty?
        raise InvalidInput, "selected capabilities were not requested by the verified OAuth token"
      end

      grant_registry.create_membership_grant(
        workspace_id:,
        membership_id:,
        managed_by_membership_id:,
        issuer: ticket.issuer,
        subject: ticket.subject,
        client_id: ticket.client_id,
        credential: credential_for(ticket),
        capabilities: normalized,
        executor: executor_for(ticket),
        client: ticket.client_id
      )
    rescue McpOauthGrantRegistry::InvalidInput => error
      raise InvalidInput, error.message
    rescue McpOauthGrantRegistry::Conflict => error
      raise Conflict, error.message
    rescue McpOauthGrantRegistry::NotFound => error
      raise NotFound, error.message
    rescue McpOauthGrantRegistry::Unauthorized => error
      raise Unauthorized, error.message
    end

    def pairing_url(token:, resource:)
      uri = URI.parse(normalize_resource(resource))
      uri.path = PAIRING_PATH
      uri.query = URI.encode_www_form(pairing_token: required_string(token, :pairing_token))
      uri.fragment = nil
      uri.to_s
    end

    def pairable_capabilities(scopes)
      normalize_capabilities(scopes) & Mcp::WorkspaceGrantPolicy::WORKSPACE_WIDE_CAPABILITIES
    end

    def pairing_expiration(token_expiration, now:)
      maximum = now + MAX_TTL
      return maximum unless token_expiration.respond_to?(:to_time)

      [ maximum, token_expiration.to_time ].min
    end
    private_class_method :pairing_expiration

    def build_ticket(payload)
      raise InvalidTicket, "pairing ticket payload must be an object" unless payload.is_a?(Hash)
      raise InvalidTicket, "pairing ticket version is unsupported" unless payload["v"] == VERSION

      Ticket.new(
        issuer: required_string(payload["issuer"], :issuer),
        subject: required_string(payload["subject"], :subject),
        client_id: required_string(payload["client_id"], :client_id),
        scopes: normalize_capabilities(payload["scopes"]).freeze,
        resource: normalize_resource(payload["resource"]),
        issued_at: parse_time(payload["issued_at"], :issued_at),
        expires_at: parse_time(payload["expires_at"], :expires_at)
      ).freeze
    end
    private_class_method :build_ticket

    def credential_for(ticket)
      "mcp-oauth:#{identity_fingerprint(ticket)}"
    end
    private_class_method :credential_for

    def executor_for(ticket)
      "oauth:#{identity_fingerprint(ticket)[0, 24]}"
    end
    private_class_method :executor_for

    def identity_fingerprint(ticket)
      Digest::SHA256.hexdigest([ ticket.issuer, ticket.subject, ticket.client_id ].join("\0"))
    end
    private_class_method :identity_fingerprint

    def normalize_capabilities(values)
      raise InvalidInput, "capabilities must be an array" unless values.is_a?(Array)

      values.map do |value|
        raise InvalidInput, "capabilities must contain non-empty strings" unless value.is_a?(String) && value.strip.present?

        value.strip
      end.uniq.sort
    end
    private_class_method :normalize_capabilities

    def normalize_resource(value)
      uri = URI.parse(required_string(value, :resource))
      unless uri.scheme&.downcase == "https" && uri.host && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
        raise InvalidInput, "resource must be an absolute HTTPS URI without query, userinfo, or fragment"
      end

      uri.to_s
    rescue URI::InvalidURIError
      raise InvalidInput, "resource must be a valid HTTPS URI"
    end
    private_class_method :normalize_resource

    def parse_time(value, field)
      raise InvalidTicket, "#{field} must be present" unless value.is_a?(String)

      Time.iso8601(value)
    rescue ArgumentError
      raise InvalidTicket, "#{field} must be an ISO 8601 timestamp"
    end
    private_class_method :parse_time

    def required_string(value, field)
      raise InvalidInput, "#{field} must be a string" unless value.is_a?(String)

      string = value.strip
      raise InvalidInput, "#{field} must be present" if string.empty?

      string
    end
    private_class_method :required_string

    def default_encryptor
      @default_encryptor ||= begin
        key = Rails.application.key_generator.generate_key(
          PURPOSE,
          ActiveSupport::MessageEncryptor.key_len
        )
        ActiveSupport::MessageEncryptor.new(key, serializer: JSON)
      end
    end
    private_class_method :default_encryptor
  end
end
