# frozen_string_literal: true

require "digest"

module Integration
  module Mcp
    class PersistedOauthGrantStore
      def resolve(claims)
        grant = McpOauthGrant.active.includes(:organization).find_by(
          issuer: claims.issuer,
          subject: claims.subject,
          client_id: claims.client_id
        )
        return unless grant

        capabilities = grant.capabilities & claims.scopes
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

      def runtime_id(grant)
        fingerprint = Digest::SHA256.hexdigest(
          [ grant.issuer, grant.subject, grant.client_id, grant.credential ].join("\0")
        )
        "mcp-oauth:#{fingerprint}"
      end
    end
  end
end
