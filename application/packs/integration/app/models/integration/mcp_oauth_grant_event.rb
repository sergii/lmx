# frozen_string_literal: true

module Integration
  class McpOauthGrantEvent < ApplicationRecord
    self.table_name = "integration_mcp_oauth_grant_events"

    include TypedId

    uses_typed_id "mcp_oauth_grant_event"

    ACTIONS = %w[created capabilities_updated revoked restored].freeze

    belongs_to :grant,
      class_name: "Integration::McpOauthGrant",
      inverse_of: :events
    belongs_to :organization

    normalizes :action, :managed_by, :reason, with: -> { _1.strip.presence }

    validates :action, inclusion: { in: ACTIONS }
    validates :managed_by, presence: true
    validates :snapshot, presence: true
    validate :organization_matches_grant

    def readonly?
      persisted?
    end

    private

    def organization_matches_grant
      return if grant.blank? || organization_id.blank?

      errors.add(:organization, "must match the grant workspace") if grant.organization_id != organization_id
    end
  end
end
