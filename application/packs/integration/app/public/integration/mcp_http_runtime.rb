# frozen_string_literal: true

module Integration
  module McpHttpRuntime
    class ConfigurationError < StandardError; end
    class Unauthenticated < StandardError; end
    class AuthenticationUnavailable < StandardError; end

    CREDENTIALS_ENV = "LMX_MCP_HTTP_CREDENTIALS"
    ALLOWED_HOSTS_ENV = "LMX_MCP_HTTP_ALLOWED_HOSTS"
    ALLOWED_ORIGINS_ENV = "LMX_MCP_HTTP_ALLOWED_ORIGINS"
    OAUTH_INTROSPECTION_ENDPOINT_ENV = "LMX_MCP_OAUTH_INTROSPECTION_ENDPOINT"
    OAUTH_INTROSPECTION_CLIENT_ID_ENV = "LMX_MCP_OAUTH_INTROSPECTION_CLIENT_ID"
    OAUTH_INTROSPECTION_CLIENT_SECRET_ENV = "LMX_MCP_OAUTH_INTROSPECTION_CLIENT_SECRET"
    OAUTH_GRANTS_ENV = "LMX_MCP_OAUTH_GRANTS"
    OAUTH_VERIFIER_ENV = [
      OAUTH_INTROSPECTION_ENDPOINT_ENV,
      OAUTH_INTROSPECTION_CLIENT_ID_ENV,
      OAUTH_INTROSPECTION_CLIENT_SECRET_ENV,
      OAUTH_GRANTS_ENV
    ].freeze

    module_function

    def build(token:, environment: ENV, oauth_requester: nil)
      identity = authenticate(
        token:,
        environment:,
        oauth_requester:
      )
      raise Unauthenticated unless identity

      allowed_hosts = list(environment, ALLOWED_HOSTS_ENV)
      if allowed_hosts.empty?
        raise ConfigurationError, "#{ALLOWED_HOSTS_ENV} must contain at least one host"
      end

      credential_source = identity.credential_source
      server = Mcp::Server.new(
        read_adapter: ReadStack.build(credential_source:),
        command_adapter: CommandStack.build(credential_source:),
        identity:,
        require_explicit_write_idempotency: true
      )

      Mcp::HttpTransport.new(
        server:,
        allowed_hosts:,
        allowed_origins: list(environment, ALLOWED_ORIGINS_ENV)
      )
    rescue Mcp::HttpCredentialStore::ConfigurationError,
      Mcp::OauthIntrospectionClient::ConfigurationError,
      Mcp::OauthGrantStore::ConfigurationError,
      McpOauthResourceMetadata::ConfigurationError,
      ArgumentError => error
      raise ConfigurationError, error.message
    rescue Mcp::OauthIntrospectionClient::Unavailable => error
      raise AuthenticationUnavailable, error.message
    end

    def authenticate(token:, environment:, oauth_requester: nil)
      bootstrap = environment[CREDENTIALS_ENV].to_s.strip
      oauth_enabled = oauth_verifier_configured?(environment)

      if bootstrap.empty? && !oauth_enabled
        raise ConfigurationError,
          "configure #{CREDENTIALS_ENV} or the complete MCP OAuth introspection verifier"
      end

      unless bootstrap.empty?
        identity = Mcp::HttpCredentialStore.new(serialized: bootstrap).authenticate(token)
        return identity if identity
      end

      return unless oauth_enabled

      oauth_identity(
        token:,
        environment:,
        requester: oauth_requester
      )
    end
    private_class_method :authenticate

    def oauth_identity(token:, environment:, requester:)
      metadata = McpOauthResourceMetadata.build(environment:)
      unless metadata.authorization_servers.one?
        raise ConfigurationError,
          "OAuth introspection currently requires exactly one advertised authorization server"
      end

      client = Mcp::OauthIntrospectionClient.new(
        endpoint: fetch_environment(environment, OAUTH_INTROSPECTION_ENDPOINT_ENV),
        issuer: metadata.authorization_servers.first.to_s,
        resource: metadata.resource.to_s,
        client_id: fetch_environment(environment, OAUTH_INTROSPECTION_CLIENT_ID_ENV),
        client_secret: fetch_environment(environment, OAUTH_INTROSPECTION_CLIENT_SECRET_ENV),
        requester:
      )
      claims = client.verify(token)
      return unless claims

      Mcp::OauthGrantStore.new(
        serialized: fetch_environment(environment, OAUTH_GRANTS_ENV)
      ).resolve(claims)
    end
    private_class_method :oauth_identity

    def oauth_verifier_configured?(environment)
      configured = OAUTH_VERIFIER_ENV.filter { !environment[_1].to_s.strip.empty? }
      return false if configured.empty?

      missing = OAUTH_VERIFIER_ENV - configured
      unless missing.empty?
        raise ConfigurationError, "incomplete MCP OAuth verifier configuration: missing #{missing.join(", ")}"
      end

      true
    end
    private_class_method :oauth_verifier_configured?

    def fetch_environment(environment, key)
      value = environment[key].to_s.strip
      raise ConfigurationError, "#{key} is required for MCP OAuth verification" if value.empty?

      value
    end
    private_class_method :fetch_environment

    def list(environment, key)
      environment[key].to_s.split(/[\s,]+/).map(&:strip).reject(&:empty?)
    end
    private_class_method :list
  end
end
