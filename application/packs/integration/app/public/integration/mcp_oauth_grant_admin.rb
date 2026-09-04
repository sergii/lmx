# frozen_string_literal: true

module Integration
  module McpOauthGrantAdmin
    class Error < StandardError; end
    class InvalidInput < Error; end
    class NotFound < Error; end
    class Unauthorized < Error; end

    module_function

    def list_grants(
      workspace_id:,
      managed_by_membership_id:,
      workspace_api: Workspace::Api,
      grant_registry: McpOauthGrantRegistry,
      grant_policy: Mcp::WorkspaceGrantPolicy.new
    )
      manager = fetch_membership!(
        workspace_api,
        workspace_id:,
        membership_id: managed_by_membership_id
      )
      authorize_manager!(grant_policy, manager)

      with_registry_errors do
        grant_registry.list_grants(workspace_id:, include_revoked: true).map do |grant|
          grant_snapshot(
            grant,
            workspace_id:,
            workspace_api:,
            grant_policy:
          )
        end.freeze
      end
    end

    def update_capabilities(
      workspace_id:,
      grant_id:,
      capabilities:,
      managed_by_membership_id:,
      workspace_api: Workspace::Api,
      grant_registry: McpOauthGrantRegistry,
      grant_policy: Mcp::WorkspaceGrantPolicy.new
    )
      manager = fetch_membership!(
        workspace_api,
        workspace_id:,
        membership_id: managed_by_membership_id
      )
      authorize_manager!(grant_policy, manager)

      with_registry_errors do
        grant_registry.update_membership_capabilities(
          workspace_id:,
          grant_id:,
          capabilities:,
          managed_by_membership_id: manager.fetch(:id),
          workspace_api:,
          grant_policy:
        )
      end
    end

    def revoke_grant(
      workspace_id:,
      grant_id:,
      managed_by_membership_id:,
      reason: nil,
      workspace_api: Workspace::Api,
      grant_registry: McpOauthGrantRegistry,
      grant_policy: Mcp::WorkspaceGrantPolicy.new
    )
      manager = fetch_membership!(
        workspace_api,
        workspace_id:,
        membership_id: managed_by_membership_id
      )
      authorize_manager!(grant_policy, manager)

      with_registry_errors do
        grant_registry.revoke_grant(
          workspace_id:,
          grant_id:,
          managed_by: manager.fetch(:id),
          reason:
        )
      end
    end

    def restore_grant(
      workspace_id:,
      grant_id:,
      managed_by_membership_id:,
      workspace_api: Workspace::Api,
      grant_registry: McpOauthGrantRegistry,
      grant_policy: Mcp::WorkspaceGrantPolicy.new
    )
      manager = fetch_membership!(
        workspace_api,
        workspace_id:,
        membership_id: managed_by_membership_id
      )
      authorize_manager!(grant_policy, manager)

      with_registry_errors do
        grant_registry.restore_grant(
          workspace_id:,
          grant_id:,
          managed_by: manager.fetch(:id)
        )
      end
    end

    def grant_snapshot(grant, workspace_id:, workspace_api:, grant_policy:)
      principal = grant.fetch("principal")
      membership = nil
      authorization_kind = "service_principal"
      workspace_capabilities = nil

      if user_principal?(principal)
        membership = fetch_membership_for_user(
          workspace_api,
          workspace_id:,
          user_id: principal
        )
        authorization_kind = membership ? "workspace_membership" : "orphaned_workspace_user"
        workspace_capabilities = membership ? grant_policy.capabilities_for(membership) : []
      end

      effective_capabilities = if grant.fetch("revoked_at")
        []
      elsif workspace_capabilities.nil?
        grant.fetch("capabilities")
      else
        grant.fetch("capabilities") & workspace_capabilities
      end

      grant.merge(
        "authorization_kind" => authorization_kind,
        "membership" => membership&.transform_keys(&:to_s),
        "workspace_capabilities" => workspace_capabilities,
        "effective_capabilities" => effective_capabilities,
        "status" => grant_status(
          grant,
          authorization_kind:,
          effective_capabilities:
        )
      ).freeze
    end
    private_class_method :grant_snapshot

    def grant_status(grant, authorization_kind:, effective_capabilities:)
      return "revoked" if grant.fetch("revoked_at")
      return "active" if authorization_kind == "service_principal"
      return "blocked" if effective_capabilities.empty?

      "active"
    end
    private_class_method :grant_status

    def fetch_membership!(workspace_api, workspace_id:, membership_id:)
      workspace_api.fetch_membership(workspace_id:, membership_id:)
    rescue Workspace::Api::InvalidInput => error
      raise InvalidInput, error.message
    rescue Workspace::Api::NotFound => error
      raise NotFound, error.message
    end
    private_class_method :fetch_membership!

    def fetch_membership_for_user(workspace_api, workspace_id:, user_id:)
      workspace_api.fetch_membership_for_user(workspace_id:, user_id:)
    rescue Workspace::Api::InvalidInput, Workspace::Api::NotFound
      nil
    end
    private_class_method :fetch_membership_for_user

    def authorize_manager!(grant_policy, membership)
      return if grant_policy.can_manage_grants?(membership)

      raise Unauthorized, "workspace membership may not administer MCP OAuth grants"
    end
    private_class_method :authorize_manager!

    def user_principal?(principal)
      TypeID.from_string(principal).prefix == "user"
    rescue TypeID::Error
      false
    end
    private_class_method :user_principal?

    def with_registry_errors
      yield
    rescue McpOauthGrantRegistry::InvalidInput => error
      raise InvalidInput, error.message
    rescue McpOauthGrantRegistry::NotFound => error
      raise NotFound, error.message
    rescue McpOauthGrantRegistry::Unauthorized => error
      raise Unauthorized, error.message
    rescue McpOauthGrantRegistry::Conflict => error
      raise InvalidInput, error.message
    end
    private_class_method :with_registry_errors
  end
end
