# frozen_string_literal: true

module Integration
  module Mcp
    class WorkspaceGrantPolicy
      INTERNAL_ROLES = %w[workspace_admin recruiting_ops_lead recruiter].freeze
      GRANT_ADMIN_ROLES = %w[workspace_admin].freeze

      WORKSPACE_WIDE_CAPABILITIES = %w[
        assess:matches
        read:applications
        read:candidates
        read:matches
        read:openings
        submit:openings
      ].freeze

      def capabilities_for(membership)
        snapshot = membership_snapshot(membership)
        return EMPTY_CAPABILITIES unless snapshot.fetch(:active)
        return EMPTY_CAPABILITIES unless INTERNAL_ROLES.include?(snapshot.fetch(:role))

        WORKSPACE_WIDE_CAPABILITIES
      end

      def can_manage_grants?(membership)
        snapshot = membership_snapshot(membership)
        snapshot.fetch(:active) && GRANT_ADMIN_ROLES.include?(snapshot.fetch(:role))
      end

      def allowed?(membership, requested_capabilities)
        requested = normalize_capabilities(requested_capabilities)
        (requested - capabilities_for(membership)).empty?
      end

      private

      EMPTY_CAPABILITIES = [].freeze

      def membership_snapshot(value)
        raise ArgumentError, "membership must be a snapshot" unless value.is_a?(Hash)

        snapshot = value.symbolize_keys
        %i[id workspace_id user_id role active client_portal].each do |field|
          raise ArgumentError, "membership snapshot is missing #{field}" unless snapshot.key?(field)
        end
        snapshot
      end

      def normalize_capabilities(values)
        raise ArgumentError, "capabilities must be an array" unless values.is_a?(Array)

        values.map(&:to_s).map(&:strip).reject(&:empty?).uniq.sort
      end
    end
  end
end
