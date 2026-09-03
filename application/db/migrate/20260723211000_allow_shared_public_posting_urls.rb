# frozen_string_literal: true

class AllowSharedPublicPostingUrls < ActiveRecord::Migration[8.1]
  def change
    remove_index :job_postings, name: "index_job_postings_on_organization_id_and_public_url"
    add_index :job_postings, %i[organization_id job_id public_url], unique: true
  end
end
