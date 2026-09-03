# frozen_string_literal: true

class AddApplicationStageEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :application_stage_events, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :application, type: :uuid, null: false, foreign_key: true
      t.references :moved_by, foreign_key: { to_table: :users }
      t.string :from_stage
      t.string :to_stage, null: false
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :application_stage_events, %i[application_id occurred_at]

    execute <<~SQL
      ALTER TABLE application_stage_events ENABLE ROW LEVEL SECURITY;
      ALTER TABLE application_stage_events FORCE ROW LEVEL SECURITY;
      CREATE POLICY organization_isolation ON application_stage_events
        USING (organization_id = current_setting('app.current_organization', true)::uuid)
        WITH CHECK (organization_id = current_setting('app.current_organization', true)::uuid);
    SQL
  end
end
