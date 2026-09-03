# frozen_string_literal: true

class CreateTasks < ActiveRecord::Migration[8.1]
  def up
    create_table :tasks, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :created_by, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.references :assigned_to, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.date :due_on
      t.datetime :completed_at
      t.timestamps

      t.index %i[organization_id completed_at due_on]
    end

    execute <<~SQL
      ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
      ALTER TABLE tasks FORCE ROW LEVEL SECURITY;
      CREATE POLICY organization_isolation ON tasks
        USING (organization_id = current_setting('app.current_organization', true)::uuid)
        WITH CHECK (organization_id = current_setting('app.current_organization', true)::uuid);
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "rolling back tenant isolation is unsafe"
  end
end
