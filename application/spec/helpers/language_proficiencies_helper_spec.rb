# frozen_string_literal: true

require "rails_helper"

RSpec.describe LanguageProficienciesHelper, type: :helper do
  it "formats CEFR levels for compact, full, and label-only views" do
    expect(helper.language_proficiency_label("b2", style: :code)).to eq("B2")
    expect(helper.language_proficiency_label("b2")).to eq("B2 · Upper-intermediate")
    expect(helper.language_proficiency_label("b2", style: :label)).to eq("Upper-intermediate")
  end

  it "renders a badge helper with the selected display style" do
    expect(helper.language_proficiency_badge("a1", style: :label)).to include("Beginner")
  end
end
