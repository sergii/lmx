# frozen_string_literal: true

module Integration
  module McpOAuthResourceMetadata
    class ConfigurationError < StandardError; end
    class NotConfigured < ConfigurationError; end

    RESOURCE_ENV = "LMX_MCP_OAUTH_RESOURCE"
    AUTHORIZATION_SERVERS_ENV = "LMX_MCP_OAUTH_AUTHORIZATION_SERVERS"
    SCOPES_ENV = "LMX_MCP_OAUTH_SCOPES"
    RESOURCE_NAME_ENV = "LMX_MCP_OAUTH_RESOURCE_NAME"
    MCP_RESOURCE_PATH = "/mcp"

    module_function

    def build(environment: ENV)
      resource = environment[RESOURCE_ENV].to_s.strip
      authorization_servers = list(environment, AUTHORIZATION_SERVERS_ENV)

      if resource.empty? && authorization_servers.empty?
        raise NotConfigured, "MCP OAuth protected resource metadata is not configured"
      end
      if resource.empty?
        raise ConfigurationError, "#{RESOURCE_ENV} is required when MCP OAuth metadata is configured"
      end
      if authorization_servers.empty?
        raise ConfigurationError, "#{AUTHORIZATION_SERVERS_ENV} must contain at least one issuer"
      end

      metadata = Mcp::ProtectedResourceMetadata.new(
        resource:,
        authorization_servers:,
        scopes_supported: list(environment, SCOPES_ENV),
        resource_name: environment[RESOURCE_NAME_ENV].presence || "LMX MCP"
      )
      unless metadata.resource.path == MCP_RESOURCE_PATH
        raise ConfigurationError, "#{RESOURCE_ENV} must identify the public #{MCP_RESOURCE_PATH} endpoint"
      end

      metadata
    rescue ArgumentError => error
      raise ConfigurationError, error.message
    end

    def challenge(environment: ENV)
      metadata = build(environment:)
      parts = [
        'Bearer realm="lmx-mcp"',
        %(resource_metadata="#{metadata.metadata_url}")
      ]
      unless metadata.scopes_supported.empty?
        parts << %(scope="#{metadata.scopes_supported.join(" ")}")
      end

      parts.join(", ")
    rescue NotConfigured
      'Bearer realm="lmx-mcp"'
    end

    def list(environment, key)
      environment[key].to_s.split(/[\s,]+/).map(&:strip).reject(&:empty?)
    end
    private_class_method :list
  end
end
