# frozen_string_literal: true

class CreateMeetings < ActiveRecord::Migration[8.1]
  def up
    create_table :meetings, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :candidate, null: false, type: :uuid, foreign_key: true
      t.references :application, type: :uuid, foreign_key: true
      t.references :created_by, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.references :reminder_task, type: :uuid, foreign_key: { to_table: :tasks }
      t.string :kind, null: false
      t.string :status, null: false, default: "scheduled"
      t.integer :sequence, null: false
      t.datetime :scheduled_at, null: false
      t.integer :duration_minutes
      t.string :meeting_url
      t.text :notes
      t.timestamps
    end

    add_index :meetings, %i[organization_id scheduled_at]
    add_index :meetings, %i[candidate_id scheduled_at]
    add_index :meetings, %i[application_id kind sequence], unique: true, where: "application_id IS NOT NULL", name: "index_meetings_on_application_kind_sequence"

    execute <<~SQL
      ALTER TABLE meetings ENABLE ROW LEVEL SECURITY;
      ALTER TABLE meetings FORCE ROW LEVEL SECURITY;
      CREATE POLICY organization_isolation ON meetings
        USING (organization_id = current_setting('app.current_organization', true)::uuid)
        WITH CHECK (organization_id = current_setting('app.current_organization', true)::uuid);
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "rolling back tenant isolation is unsafe"
  end
end
