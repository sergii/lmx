# frozen_string_literal: true

class EnrichCandidateProfiles < ActiveRecord::Migration[8.1]
  def change
    change_table :candidates, bulk: true do |t|
      t.string :linkedin_url
      t.string :github_url
      t.string :english_level
      t.string :salary_expectation
      t.string :availability
      t.string :notice_period
      t.string :work_authorization
      t.string :skills, array: true, null: false, default: []
      t.string :tags, array: true, null: false, default: []
      t.text :notes
    end
  end
end
