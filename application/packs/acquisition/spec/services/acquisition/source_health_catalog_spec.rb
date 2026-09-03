# frozen_string_literal: true

require "rails_helper"

RSpec.describe Acquisition::SourceHealth, type: :model do
  it "lists operational health only for active enabled catalog sources" do
    expect(described_class.all.map { _1.fetch(:source_key) }).to eq(
      [ "dou", "djinni", "work_ua", "robota_ua", "remoteok" ]
    )
  end
end
