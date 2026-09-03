# frozen_string_literal: true

module Integration
  module CommandStack
    module_function

    def build(
      credential_source:,
      workspace_api: Workspace::Api,
      match_api: Intelligence::Api,
      reliability_api: Platform::Reliability::Api,
      command_executor: Platform::Reliability::CommandExecutor
    )
      workspace_scope = Command::Adapters::PublicApiWorkspaceScope.new(
        workspace_api:,
        not_found_errors: [ Workspace::Api::NotFound ]
      )
      authorization = Command::CapabilityAuthorization.new(credential_source:)
      command_router = Command::Router.new(
        routes: {
          "matches.assess.v1" => Command::Adapters::MatchesAssess.new(
            match_api:,
            invalid_input_errors: [ Intelligence::Api::InvalidInput ],
            not_found_errors: [ Intelligence::Api::NotFound ],
            contract_violation_errors: [ Intelligence::Api::ContractViolation ]
          )
        }
      )
      dispatcher = Command::Dispatcher.new(
        command_port: command_router,
        authorization_port: authorization,
        workspace_scope:,
        reliability_api:,
        command_executor:
      )

      Mcp::CommandAdapter.new(dispatcher:)
    end
  end
end
