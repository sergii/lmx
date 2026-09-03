# frozen_string_literal: true

class CreateClientDecisions < ActiveRecord::Migration[8.1]
  def up
    create_table :client_decisions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :application, null: false, type: :uuid, foreign_key: true, index: { unique: true }
      t.references :decided_by, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.string :decision, null: false
      t.text :note
      t.datetime :decided_at, null: false
      t.timestamps
    end

    add_index :client_decisions, %i[organization_id decided_at]

    execute <<~SQL
      ALTER TABLE client_decisions ENABLE ROW LEVEL SECURITY;
      ALTER TABLE client_decisions FORCE ROW LEVEL SECURITY;
      CREATE POLICY organization_isolation ON client_decisions
        USING (organization_id = current_setting('app.current_organization', true)::uuid)
        WITH CHECK (organization_id = current_setting('app.current_organization', true)::uuid);
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "rolling back tenant isolation is unsafe"
  end
end
