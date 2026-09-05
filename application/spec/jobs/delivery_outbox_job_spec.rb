# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeliveryOutboxJob, type: :job do
  let(:workspace_id) { TypeID.from_uuid("org", SecureRandom.uuid).to_s }
  let(:client) { instance_double(Delivery::Telegram::Client) }
  let(:environment) do
    {
      "TELEGRAM_BOT_TOKEN" => "telegram-token",
      "TELEGRAM_CHAT_ID" => "telegram-chat"
    }
  end
  let(:profile) do
    {
      "source_priorities" => {
        "dou" => { "lane" => "local_fast" }
      },
      "notification" => {
        "primary_surface" => "telegram",
        "action_priority_threshold" => 87,
        "prefer_near_real_time_for" => [ "new_local_fast_opportunity" ]
      }
    }
  end

  before do
    allow(Lmx::Configuration).to receive(:default_profile).and_return(profile)
    allow(Delivery::Telegram::Client).to receive(:new).and_return(client)
    allow(Delivery::Telegram::Publisher).to receive(:call).and_return(0)
    allow(Workspace::Api).to receive(:with_workspace).and_yield
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("LMX_PUBLIC_BASE_URL").and_return("https://lmx.example.test")
  end

  it "uses an explicit workspace without requiring the Phase 0 workspace fallback" do
    allow(Delivery::RuntimeRequirements).to receive(:fetch!)
      .with("TELEGRAM_BOT_TOKEN", "TELEGRAM_CHAT_ID")
      .and_return(environment)

    described_class.new.perform(workspace_id:)

    expect(Workspace::Api).to have_received(:with_workspace).with(workspace_id:)
    expect(Delivery::Telegram::Publisher).to have_received(:call).with(
      client:,
      profile:,
      public_base_url: "https://lmx.example.test"
    )
  end

  it "keeps the recurring Phase 0 workspace fallback for the no-argument schedule" do
    fallback_environment = environment.merge("LMX_PHASE0_WORKSPACE_ID" => workspace_id)
    allow(Delivery::RuntimeRequirements).to receive(:fetch!)
      .with("TELEGRAM_BOT_TOKEN", "TELEGRAM_CHAT_ID", "LMX_PHASE0_WORKSPACE_ID")
      .and_return(fallback_environment)

    described_class.new.perform

    expect(Workspace::Api).to have_received(:with_workspace).with(workspace_id:)
    expect(Delivery::Telegram::Publisher).to have_received(:call).with(
      client:,
      profile:,
      public_base_url: "https://lmx.example.test"
    )
  end
end
