# frozen_string_literal: true

class AddJobBriefsAndPostings < ActiveRecord::Migration[8.1]
  def up
    add_column :jobs, :description, :text

    create_table :sourcing_briefs, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :job, null: false, type: :uuid, foreign_key: true, index: { unique: true }
      t.references :approved_by, type: :uuid, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "draft"
      t.text :summary
      t.string :must_haves, array: true, null: false, default: []
      t.string :nice_to_haves, array: true, null: false, default: []
      t.string :exclusions, array: true, null: false, default: []
      t.string :search_queries, array: true, null: false, default: []
      t.string :location_preferences, array: true, null: false, default: []
      t.string :language_requirement
      t.text :interview_focus
      t.datetime :approved_at
      t.timestamps
    end
    add_index :sourcing_briefs, %i[organization_id status]

    create_table :job_postings, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :job, null: false, type: :uuid, foreign_key: true
      t.string :channel, null: false
      t.string :status, null: false, default: "draft"
      t.string :title
      t.string :public_url, null: false
      t.text :content_snapshot
      t.datetime :published_at
      t.datetime :closed_at
      t.timestamps
    end
    add_index :job_postings, %i[organization_id job_id status]
    add_index :job_postings, %i[organization_id public_url], unique: true

    %w[sourcing_briefs job_postings].each do |table|
      execute <<~SQL
        ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY;
        ALTER TABLE #{table} FORCE ROW LEVEL SECURITY;
        CREATE POLICY organization_isolation ON #{table}
          USING (organization_id = current_setting('app.current_organization', true)::uuid)
          WITH CHECK (organization_id = current_setting('app.current_organization', true)::uuid);
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "rolling back tenant isolation is unsafe"
  end
end
