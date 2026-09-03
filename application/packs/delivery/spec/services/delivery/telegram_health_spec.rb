# frozen_string_literal: true

require "rails_helper"

RSpec.describe Delivery::TelegramHealth, type: :model do
  class FakeTelegramProbeClient
    class << self
      attr_reader :last_init

      def new(**attributes)
        @last_init = attributes
        allocate
      end
    end

    def probe!
      true
    end
  end

  it "probes Telegram without exposing configured credentials" do
    env = {
      "TELEGRAM_BOT_TOKEN" => "secret-token",
      "TELEGRAM_CHAT_ID" => "-100123"
    }

    result = described_class.check(env:, client_class: FakeTelegramProbeClient)

    expect(result).to eq(reachable: true)
    expect(FakeTelegramProbeClient.last_init).to eq(token: "secret-token", chat_id: "-100123")
    expect(JSON.generate(result)).not_to include("secret-token", "-100123")
  end

  it "fails explicitly when Telegram configuration is missing" do
    expect do
      described_class.check(env: {}, client_class: FakeTelegramProbeClient)
    end.to raise_error(Delivery::RuntimeRequirements::MissingEnvironmentVariables, /TELEGRAM_BOT_TOKEN/)
  end
end
