# frozen_string_literal: true

module Workspace
  module Api
    class Error < StandardError; end
    class InvalidInput < Error; end
    class NotFound < Error; end

    module_function

    def with_workspace(workspace_id:, membership_id: nil, &block)
      raise InvalidInput, "workspace_id is required" if workspace_id.to_s.strip.empty?
      raise InvalidInput, "block is required" unless block
      if !membership_id.nil? && membership_id.to_s.strip.empty?
        raise InvalidInput, "membership_id must be omitted or present"
      end

      workspace = resolve_workspace(workspace_id)
      membership = resolve_membership(membership_id, workspace)

      WorkspaceContext.with(workspace, membership:, &block)
    end

    def fetch_membership(workspace_id:, membership_id:)
      workspace = resolve_workspace(workspace_id)
      membership = resolve_membership(required_string(membership_id, :membership_id), workspace)
      membership_snapshot(membership)
    end

    def fetch_membership_for_user(workspace_id:, user_id:)
      workspace = resolve_workspace(workspace_id)
      user = User.find_by_typed_id!(required_string(user_id, :user_id))
      membership = Membership.find_by!(organization: workspace, user:)
      membership_snapshot(membership)
    rescue ActiveRecord::RecordNotFound
      raise NotFound, "membership not found in workspace"
    end

    def resolve_workspace(workspace_id)
      Organization.find_by_typed_id!(workspace_id)
    rescue ActiveRecord::RecordNotFound
      raise NotFound, "workspace not found"
    end
    private_class_method :resolve_workspace

    def resolve_membership(membership_id, workspace)
      return if membership_id.nil?

      membership = Membership.find_by_typed_id!(membership_id)
      raise ActiveRecord::RecordNotFound unless membership.organization_id == workspace.id

      membership
    rescue ActiveRecord::RecordNotFound
      raise NotFound, "membership not found in workspace"
    end
    private_class_method :resolve_membership

    def membership_snapshot(membership)
      {
        id: membership.typed_id,
        workspace_id: membership.organization.typed_id,
        user_id: membership.user.typed_id,
        role: membership.role,
        active: membership.active?,
        client_portal: membership.client_portal?
      }.freeze
    end
    private_class_method :membership_snapshot

    def required_string(value, field)
      unless value.is_a?(String) && value.strip.present?
        raise InvalidInput, "#{field} is required"
      end

      value.strip
    end
    private_class_method :required_string
  end
end
