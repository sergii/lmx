# frozen_string_literal: true

module Integration
  module McpHttpRuntime
    class ConfigurationError < StandardError; end
    class Unauthenticated < StandardError; end

    CREDENTIALS_ENV = "LMX_MCP_HTTP_CREDENTIALS"
    ALLOWED_HOSTS_ENV = "LMX_MCP_HTTP_ALLOWED_HOSTS"
    ALLOWED_ORIGINS_ENV = "LMX_MCP_HTTP_ALLOWED_ORIGINS"

    module_function

    def build(token:, environment: ENV)
      serialized = environment[CREDENTIALS_ENV].to_s.strip
      if serialized.empty?
        raise ConfigurationError, "#{CREDENTIALS_ENV} is required for MCP HTTP"
      end

      store = Mcp::HttpCredentialStore.new(serialized:)
      identity = store.authenticate(token)
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
    rescue Mcp::HttpCredentialStore::ConfigurationError, ArgumentError => error
      raise ConfigurationError, error.message
    end

    def list(environment, key)
      environment[key].to_s.split(/[\s,]+/).map(&:strip).reject(&:empty?)
    end
    private_class_method :list
  end
end
