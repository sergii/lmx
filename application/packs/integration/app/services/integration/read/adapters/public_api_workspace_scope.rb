# frozen_string_literal: true

module Integration
  module Read
    module Adapters
      class PublicApiWorkspaceScope < Ports::WorkspaceScope
        def initialize(workspace_api:, not_found_errors: [])
          unless workspace_api.respond_to?(:with_workspace)
            raise Error::InvalidInput.new("workspace_api must respond to with_workspace")
          end
          unless valid_not_found_errors?(not_found_errors)
            raise Error::InvalidInput.new("not_found_errors must contain StandardError subclasses")
          end

          @workspace_api = workspace_api
          @not_found_errors = not_found_errors.dup.freeze
          freeze
        end

        def call(context, &block)
          unless context.respond_to?(:workspace_id)
            raise Error::InvalidInput.new("workspace context must expose workspace_id")
          end
          unless context.workspace_id.is_a?(String) && !context.workspace_id.strip.empty?
            raise Error::InvalidInput.new("workspace_id is required")
          end
          raise Error::InvalidInput.new("workspace scope block is required") unless block

          @workspace_api.with_workspace(workspace_id: context.workspace_id, &block)
        rescue StandardError => error
          raise unless not_found_error?(error)

          raise Error::NotFound.new(
            "Workspace not found",
            details: { workspace_id: context.workspace_id }
          )
        end

        private

        def valid_not_found_errors?(errors)
          errors.is_a?(Array) && errors.all? do |error_class|
            error_class.is_a?(Class) && error_class < StandardError
          end
        end

        def not_found_error?(error)
          @not_found_errors.any? { |error_class| error.is_a?(error_class) }
        end
      end
    end
  end
end
