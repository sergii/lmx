# frozen_string_literal: true

class AddWorkspaceOnboarding < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :onboarding_completed_at, :datetime
    add_column :organizations, :onboarding_use_cases, :string, array: true, default: [], null: false
  end
end
