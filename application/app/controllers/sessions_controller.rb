# frozen_string_literal: true

class SessionsController < InertiaController
  skip_before_action :authenticate, only: %i[new create]
  before_action :require_no_authentication, only: %i[new create]
  before_action :set_session, only: :destroy

  def new
  end

  def create
    if user = User.authenticate_by(email: params[:email], password: params[:password])
      @session = user.sessions.create!
      cookies.signed.permanent[:session_token] = { value: @session.typed_id, httponly: true }

      memberships = user.memberships.active
      destination = if memberships.none?
        onboarding_profile_path
      elsif memberships.one? && pending_post_authentication_return_path
        consume_post_authentication_return_path
      else
        organizations_path
      end

      redirect_to destination, notice: "Signed in successfully"
    else
      redirect_to sign_in_path, alert: "That email or password is incorrect"
    end
  end

  def destroy
    @session.destroy!
    Current.session = nil
    redirect_to settings_sessions_path, notice: "That session has been logged out", inertia: { clear_history: true }
  end

  private

  def set_session
    @session = Current.user.sessions.find(Session.typed_id_value(params[:id]))
  end
end
