# frozen_string_literal: true

require "digest"

module Integration
  module Mcp
    class PersistedOauthGrantStore
      def initialize(workspace_api: Workspace::Api, grant_policy: WorkspaceGrantPolicy.new)
        @workspace_api = workspace_api
        @grant_policy = grant_policy
      end

      def resolve(claims)
        grant = McpOauthGrant.active.includes(:organization).find_by(
          issuer: claims.issuer,
          subject: claims.subject,
          client_id: claims.client_id
        )
        return unless grant

        capabilities = grant.capabilities & claims.scopes
        workspace_capabilities = workspace_capabilities_for(grant)
        capabilities &= workspace_capabilities if workspace_capabilities
        return if capabilities.empty?

        RuntimeIdentity.new(
          workspace_id: grant.workspace_id,
          principal: grant.principal,
          credential: grant.credential,
          actor: grant.actor,
          executor: grant.executor,
          client: grant.client,
          capabilities:,
          runtime_id: runtime_id(grant)
        )
      end

      private

      def workspace_capabilities_for(grant)
        return unless user_principal?(grant.principal)

        membership = @workspace_api.fetch_membership_for_user(
          workspace_id: grant.workspace_id,
          user_id: grant.principal
        )
        @grant_policy.capabilities_for(membership)
      rescue Workspace::Api::InvalidInput, Workspace::Api::NotFound
        []
      end

      def user_principal?(principal)
        TypeID.from_string(principal).prefix == "user"
      rescue TypeID::Error
        false
      end

      def runtime_id(grant)
        fingerprint = Digest::SHA256.hexdigest(
          [ grant.issuer, grant.subject, grant.client_id, grant.credential ].join("\0")
        )
        "mcp-oauth:#{fingerprint}"
      end
    end
  end
end
