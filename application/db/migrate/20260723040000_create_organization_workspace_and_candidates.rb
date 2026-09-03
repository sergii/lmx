# frozen_string_literal: true

class CreateOrganizationWorkspaceAndCandidates < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end
    add_index :organizations, :slug, unique: true

    create_table :memberships, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.string :role, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :memberships, %i[user_id organization_id], unique: true
    add_index :memberships, %i[organization_id role]

    create_table :candidates, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email
      t.string :location
      t.string :time_zone
      t.string :source
      t.string :consent_status, null: false, default: "unknown"
      t.timestamps
    end
    add_index :candidates, %i[organization_id last_name first_name]
    add_index :candidates, %i[organization_id email], unique: true, where: "email IS NOT NULL"

    execute <<~SQL
      ALTER TABLE candidates ENABLE ROW LEVEL SECURITY;
      ALTER TABLE candidates FORCE ROW LEVEL SECURITY;
      CREATE POLICY organization_isolation ON candidates
        USING (organization_id = current_setting('app.current_organization', true)::uuid)
        WITH CHECK (organization_id = current_setting('app.current_organization', true)::uuid);
    SQL
  end
end
