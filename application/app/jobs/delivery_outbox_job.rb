# frozen_string_literal: true

class DeliveryOutboxJob < ApplicationJob
  queue_as :delivery

  def perform(workspace_id: nil)
    explicit_workspace_id = workspace_id.to_s.strip.presence
    required = [ "TELEGRAM_BOT_TOKEN", "TELEGRAM_CHAT_ID" ]
    required << "LMX_PHASE0_WORKSPACE_ID" unless explicit_workspace_id
    environment = Delivery::RuntimeRequirements.fetch!(*required)
    workspace_id = explicit_workspace_id || environment.fetch("LMX_PHASE0_WORKSPACE_ID")
    notification = Lmx::Configuration.default_profile.fetch("notification", {})
    action_priority_threshold = notification.fetch(
      "action_priority_threshold",
      Delivery::Telegram::NotificationPolicy::DEFAULT_ACTION_PRIORITY_THRESHOLD
    )

    Workspace::Api.with_workspace(workspace_id:) do
      Delivery::Telegram::Publisher.call(
        client: Delivery::Telegram::Client.new(
          token: environment.fetch("TELEGRAM_BOT_TOKEN"),
          chat_id: environment.fetch("TELEGRAM_CHAT_ID")
        ),
        action_priority_threshold:
      )
    end
  end
end
