# frozen_string_literal: true

class AddClientPortalIsolationSpine < ActiveRecord::Migration[8.1]
  def change
    add_reference :memberships, :client_company, type: :uuid, foreign_key: true

    add_column :applications, :client_visible, :boolean, null: false, default: false
    add_column :applications, :client_portal_id, :string
    add_index :applications, :client_portal_id, unique: true
    add_index :applications, %i[organization_id client_visible stage]

    reversible do |direction|
      direction.up do
        execute <<~SQL
          UPDATE applications
          SET client_portal_id = 'application_' || replace(gen_random_uuid()::text, '-', '')
          WHERE client_portal_id IS NULL;
        SQL
        change_column_null :applications, :client_portal_id, false
      end
    end

    add_column :candidates, :erased_at, :datetime
    add_index :candidates, :erased_at

    create_table :audit_events, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.string :action, null: false
      t.string :subject_type, null: false
      t.uuid :subject_id, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :audit_events, %i[organization_id subject_type subject_id occurred_at], name: "index_audit_events_on_subject"

    execute <<~SQL
      ALTER TABLE audit_events ENABLE ROW LEVEL SECURITY;
      ALTER TABLE audit_events FORCE ROW LEVEL SECURITY;
      CREATE POLICY organization_isolation ON audit_events
        USING (organization_id = current_setting('app.current_organization', true)::uuid)
        WITH CHECK (organization_id = current_setting('app.current_organization', true)::uuid);
    SQL
  end
end
