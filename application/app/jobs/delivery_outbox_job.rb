# frozen_string_literal: true

class DeliveryOutboxJob < ApplicationJob
  queue_as :delivery

  def perform(workspace_id: nil)
    environment = Delivery::RuntimeRequirements.fetch!(
      "LMX_PHASE0_WORKSPACE_ID",
      "TELEGRAM_BOT_TOKEN",
      "TELEGRAM_CHAT_ID"
    )
    workspace_id = workspace_id.to_s.strip.presence || environment.fetch("LMX_PHASE0_WORKSPACE_ID")

    Workspace::Api.with_workspace(workspace_id:) do
      Delivery::Telegram::Publisher.call(
        client: Delivery::Telegram::Client.new(
          token: environment.fetch("TELEGRAM_BOT_TOKEN"),
          chat_id: environment.fetch("TELEGRAM_CHAT_ID")
        )
      )
    end
  end
end
