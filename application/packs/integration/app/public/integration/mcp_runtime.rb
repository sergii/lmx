# frozen_string_literal: true

module Integration
  module McpRuntime
    REQUIRED_ENV = %w[
      LMX_MCP_WORKSPACE_ID
      LMX_MCP_PRINCIPAL
      LMX_MCP_CREDENTIAL
      LMX_MCP_CAPABILITIES
    ].freeze

    module_function

    def build(environment: ENV)
      identity = Mcp::RuntimeIdentity.new(
        workspace_id: fetch_environment(environment, "LMX_MCP_WORKSPACE_ID"),
        principal: fetch_environment(environment, "LMX_MCP_PRINCIPAL"),
        credential: fetch_environment(environment, "LMX_MCP_CREDENTIAL"),
        actor: optional_environment(environment, "LMX_MCP_ACTOR") || fetch_environment(environment, "LMX_MCP_PRINCIPAL"),
        executor: optional_environment(environment, "LMX_MCP_EXECUTOR") || "mcp:stdio",
        client: optional_environment(environment, "LMX_MCP_CLIENT") || "lmx-mcp-local",
        capabilities: capabilities(environment)
      )
      credential_source = identity.credential_source

      Mcp::Server.new(
        read_adapter: ReadStack.build(credential_source:),
        command_adapter: CommandStack.build(credential_source:),
        identity:
      )
    end

    def capabilities(environment)
      raw = fetch_environment(environment, "LMX_MCP_CAPABILITIES")
      raw.split(/[\s,]+/).map(&:strip).reject(&:empty?)
    end
    private_class_method :capabilities

    def fetch_environment(environment, key)
      value = optional_environment(environment, key)
      return value if value

      raise ArgumentError, "#{key} is required for the MCP runtime"
    end
    private_class_method :fetch_environment

    def optional_environment(environment, key)
      value = environment[key].to_s.strip
      value unless value.empty?
    end
    private_class_method :optional_environment
  end
end
