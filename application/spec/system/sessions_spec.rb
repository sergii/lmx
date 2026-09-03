# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions", type: :system do
  fixtures :users

  it "signs in and shows the dashboard" do
    visit sign_in_path

    fill_in "Email address", with: users(:one).email
    fill_in "Password", with: "Secret1*3*5*"
    click_on "Log in"

      expect(page).to have_current_path(onboarding_profile_path)
      expect(page).to have_text("Let’s get to know you")
  end
end
