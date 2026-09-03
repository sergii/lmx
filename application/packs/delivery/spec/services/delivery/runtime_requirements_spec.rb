# frozen_string_literal: true

require "rails_helper"

RSpec.describe Delivery::RuntimeRequirements do
  let(:complete_env) do
    {
      "LMX_PHASE0_WORKSPACE_ID" => "org_01k00000000000000000000000",
      "TELEGRAM_BOT_TOKEN" => "token",
      "TELEGRAM_CHAT_ID" => "123456"
    }
  end

  it "fails production startup with every missing required variable in the message" do
    expect do
      described_class.validate!(environment: "production", env: {})
    end.to raise_error(Delivery::RuntimeRequirements::MissingEnvironmentVariables) { |error|
      expect(error.message).to include("LMX_PHASE0_WORKSPACE_ID")
      expect(error.message).to include("TELEGRAM_BOT_TOKEN")
      expect(error.message).to include("TELEGRAM_CHAT_ID")
      expect(error.message).to include("Please set the missing variables")
    }
  end

  it "treats blank values as missing" do
    env = complete_env.merge("TELEGRAM_BOT_TOKEN" => "   ")

    expect do
      described_class.validate!(environment: "production", env:)
    end.to raise_error(
      Delivery::RuntimeRequirements::MissingEnvironmentVariables,
      /TELEGRAM_BOT_TOKEN/
    )
  end

  it "accepts a complete production environment" do
    expect(described_class.validate!(environment: "production", env: complete_env)).to be(true)
  end

  it "does not require production runtime secrets in test or development" do
    expect(described_class.validate!(environment: "test", env: {})).to be(true)
    expect(described_class.validate!(environment: "development", env: {})).to be(true)
  end

  it "allows the explicit dummy-secret asset build phase" do
    env = { "SECRET_KEY_BASE_DUMMY" => "1" }

    expect(described_class.validate!(environment: "production", env:)).to be(true)
  end

  it "returns stripped values for runtime consumers" do
    env = complete_env.merge("TELEGRAM_CHAT_ID" => " 123456 ")

    values = described_class.fetch!("TELEGRAM_CHAT_ID", env:)

    expect(values).to eq("TELEGRAM_CHAT_ID" => "123456")
    expect(values).to be_frozen
  end
end
