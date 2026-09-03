# frozen_string_literal: true

class Settings::SessionsController < InertiaController
  def index
    sessions = Current.user.sessions.order(created_at: :desc)

    render inertia: { sessions: sessions.map { |session| session.slice(:user_agent, :ip_address, :created_at).merge(id: session.typed_id) } }
  end
end
