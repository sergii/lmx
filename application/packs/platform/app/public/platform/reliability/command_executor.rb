# frozen_string_literal: true

module Platform
  module Reliability
    class CommandExecutor
      class InvalidInput < Api::InvalidInput; end

      class << self
        def call(command_id:, started_at: Time.current)
          raise InvalidInput, "command execution block is required" unless block_given?

          executed = false
          replayed = false
          command = ActiveRecord::Base.transaction do
            current = Api.start_command(command_id:, started_at:)

            if current.fetch(:status) == "succeeded"
              replayed = true
              current
            else
              executed = true
              result = yield
              Api.complete_command(command_id:, result:)
            end
          end

          execution_snapshot(command:, replayed:)
        rescue StandardError => error
          record_failure(command_id:, started_at:, error:) if executed
          raise
        end

        private

        def record_failure(command_id:, started_at:, error:)
          ActiveRecord::Base.transaction do
            current = Api.start_command(command_id:, started_at:)
            return if current.fetch(:status) == "succeeded"

            Api.fail_command(
              command_id:,
              error: {
                error_class: error.class.name,
                message: error.message
              }
            )
          end
        rescue Api::NotFound
          # Preserve the original execution error if the Inbox record disappeared unexpectedly.
          nil
        end

        def execution_snapshot(command:, replayed:)
          {
            replayed:,
            result: command.fetch(:result),
            command:
          }.freeze
        end
      end
    end
  end
end
