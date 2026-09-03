# frozen_string_literal: true

class EnforceUuidUserReferences < ActiveRecord::Migration[8.1]
  def change
    change_column_null :sessions, :user_id, false
    change_column_null :memberships, :user_id, false
  end
end
