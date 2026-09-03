# frozen_string_literal: true

module Integration
  module ReadStack
    module_function

    def build(
      credential_source:,
      workspace_api: Workspace::Api,
      candidate_api: TalentProfile::Api,
      opening_api: MarketCatalog::Api,
      match_api: Intelligence::Api
    )
      workspace_scope = Read::Adapters::PublicApiWorkspaceScope.new(
        workspace_api:,
        not_found_errors: [ Workspace::Api::NotFound ]
      )
      capability_resolver = Read::CredentialCapabilityResolver.new(credential_source:)
      authorization = Read::CapabilityAuthorization.new(capability_resolver:)

      query_router = Read::QueryRouter.new(
        routes: {
          "openings.search.v1" => Read::Adapters::OpeningsSearch.new(opening_api:, workspace_scope:),
          "openings.get.v1" => Read::Adapters::OpeningsGet.new(
            opening_api:,
            workspace_scope:,
            not_found_errors: [ MarketCatalog::Api::NotFound ]
          ),
          "candidates.get.v1" => Read::Adapters::CandidatesGet.new(
            candidate_api:,
            workspace_scope:,
            not_found_errors: [ TalentProfile::Api::NotFound ]
          ),
          "candidates.profile.v1" => Read::Adapters::CandidateProfileGet.new(
            candidate_api:,
            workspace_scope:,
            not_found_errors: [ TalentProfile::Api::NotFound ]
          ),
          "matches.get.v1" => Read::Adapters::MatchesGet.new(
            match_api:,
            workspace_scope:,
            not_found_errors: [ Intelligence::Api::NotFound ]
          )
        }
      )

      dispatcher = Read::Dispatcher.new(
        query_port: query_router,
        authorization_port: authorization
      )

      Mcp::ReadAdapter.new(dispatcher:)
    end
  end
end
