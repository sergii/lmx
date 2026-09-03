# frozen_string_literal: true

class RenameTenantAdminToWorkspaceAdmin < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE memberships SET role = 'workspace_admin' WHERE role = 'tenant_admin'"
  end

  def down
    execute "UPDATE memberships SET role = 'tenant_admin' WHERE role = 'workspace_admin'"
  end
end
