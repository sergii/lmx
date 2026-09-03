# frozen_string_literal: true

module Integration
  module Command
    module Adapters
      class PublicApiWorkspaceScope
        def initialize(workspace_api:, not_found_errors: [])
          unless workspace_api.respond_to?(:with_workspace)
            raise Error::InvalidInput.new("workspace_api must respond to with_workspace")
          end
          unless valid_errors?(not_found_errors)
            raise Error::InvalidInput.new("not_found_errors must contain StandardError subclasses")
          end

          @workspace_api = workspace_api
          @not_found_errors = not_found_errors.dup.freeze
          freeze
        end

        def call(context, &block)
          unless context.is_a?(Context)
            raise Error::InvalidInput.new("workspace context must be Integration::Command::Context")
          end
          raise Error::InvalidInput.new("workspace scope block is required") unless block

          @workspace_api.with_workspace(workspace_id: context.workspace_id, &block)
        rescue StandardError => error
          raise unless @not_found_errors.any? { |error_class| error.is_a?(error_class) }

          raise Error::NotFound.new("Workspace not found", details: { workspace_id: context.workspace_id })
        end

        private

        def valid_errors?(errors)
          errors.is_a?(Array) && errors.all? { |error_class| error_class.is_a?(Class) && error_class < StandardError }
        end
      end
    end
  end
end
