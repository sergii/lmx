# frozen_string_literal: true

class WorkspaceContext
  class MissingWorkspace < ArgumentError; end

  class << self
    def with(workspace, membership: nil)
      raise MissingWorkspace, "workspace is required" unless workspace

      connection = ActiveRecord::Base.connection
      previous_organization = Current.organization
      previous_membership = Current.membership
      previous_setting = connection.select_value("SELECT current_setting('app.current_organization', true)")

      Current.organization = workspace
      Current.membership = membership
      set_database_workspace(connection, workspace.id)

      yield
    ensure
      restore_database_workspace(connection, previous_setting) if connection
      Current.organization = previous_organization
      Current.membership = previous_membership
    end

    private

    def set_database_workspace(connection, workspace_id)
      connection.execute(
        "SELECT set_config('app.current_organization', #{connection.quote(workspace_id.to_s)}, false)"
      )
    end

    def restore_database_workspace(connection, previous_setting)
      if previous_setting.present?
        connection.execute(
          "SELECT set_config('app.current_organization', #{connection.quote(previous_setting)}, false)"
        )
      else
        connection.execute("RESET app.current_organization")
      end
    end
  end
end
