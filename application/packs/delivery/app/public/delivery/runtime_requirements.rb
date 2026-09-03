# frozen_string_literal: true

module Delivery
  module RuntimeRequirements
    class MissingEnvironmentVariables < StandardError
      def initialize(keys)
        formatted_keys = keys.map { |key| "  - #{key}" }.join("\n")

        super(<<~MESSAGE.strip)
          LMX cannot start because required environment variables are missing:
          #{formatted_keys}
          Please set the missing variables before starting any production server, worker, or release process.
        MESSAGE
      end
    end

    REQUIRED_PRODUCTION_ENV = %w[
      LMX_PHASE0_WORKSPACE_ID
      TELEGRAM_BOT_TOKEN
      TELEGRAM_CHAT_ID
    ].freeze

    module_function

    def validate!(environment: Rails.env, env: ENV)
      return true unless environment.to_s == "production"
      return true if env["SECRET_KEY_BASE_DUMMY"].to_s == "1"

      fetch!(*REQUIRED_PRODUCTION_ENV, env:)
      true
    end

    def fetch!(*keys, env: ENV)
      missing = keys.select { |key| env[key].to_s.strip.empty? }
      raise MissingEnvironmentVariables, missing if missing.any?

      keys.to_h { |key| [ key, env.fetch(key).to_s.strip ] }.freeze
    end
  end
end
