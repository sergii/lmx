# frozen_string_literal: true

class HomeController < InertiaController
  skip_before_action :authenticate
  before_action :perform_authentication

  def index
    return unless Current.user

    redirect_to(Current.user.memberships.active.exists? ? home_path : onboarding_profile_path)
  end
end
