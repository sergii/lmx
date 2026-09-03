# frozen_string_literal: true

class Session < ApplicationRecord
  include TypedId

  uses_typed_id "session"

  belongs_to :user

  before_create do
    self.user_agent = Current.user_agent
    self.ip_address = Current.ip_address
  end
end
