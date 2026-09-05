# frozen_string_literal: true

class DeliveryOutboxJob < ApplicationJob
  queue_as :delivery

  def perform(workspace_id: nil)
    explicit_workspace_id = workspace_id.to_s.strip.presence
    required = [ "TELEGRAM_BOT_TOKEN", "TELEGRAM_CHAT_ID" ]
    required << "LMX_PHASE0_WORKSPACE_ID" unless explicit_workspace_id
    environment = Delivery::RuntimeRequirements.fetch!(*required)
    workspace_id = explicit_workspace_id || environment.fetch("LMX_PHASE0_WORKSPACE_ID")
    profile = Lmx::Configuration.default_profile

    Workspace::Api.with_workspace(workspace_id:) do
      Delivery::Telegram::Publisher.call(
        client: Delivery::Telegram::Client.new(
          token: environment.fetch("TELEGRAM_BOT_TOKEN"),
          chat_id: environment.fetch("TELEGRAM_CHAT_ID")
        ),
        profile:,
        public_base_url: ENV["LMX_PUBLIC_BASE_URL"].to_s.strip.presence
      )
    end
  end
end
