# frozen_string_literal: true

require "rails_helper"
require "stringio"

RSpec.describe Organization, type: :model do
  it "accepts a supported workspace logo" do
    organization = described_class.new(name: "Logo workspace", slug: "logo-workspace")
    organization.logo.attach(io: StringIO.new("image"), filename: "logo.svg", content_type: "image/svg+xml")

    expect(organization).to be_valid
  end

  it "rejects an unsupported workspace logo" do
    organization = described_class.new(name: "Unsafe logo workspace", slug: "unsafe-logo-workspace")
    organization.logo.attach(io: StringIO.new("executable"), filename: "logo.exe", content_type: "application/octet-stream")

    expect(organization).to be_invalid
    expect(organization.errors[:logo]).to include("must be a PNG, JPEG, WebP, or SVG")
  end
end
