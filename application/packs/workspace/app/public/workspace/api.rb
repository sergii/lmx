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
  end
end
