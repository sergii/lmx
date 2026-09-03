# frozen_string_literal: true

class EnsureUuidUserIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :users, :id, unique: true unless index_exists?(:users, :id)
  end
end
