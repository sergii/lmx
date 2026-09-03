# frozen_string_literal: true

module TalentProfile
  module WorkspaceGuard
    module_function

    def current!
      Current.organization || raise(WorkspaceContext::MissingWorkspace, "workspace is required")
    end
  end
end
