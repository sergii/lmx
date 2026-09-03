# frozen_string_literal: true

class CreateWorkspaceInvitations < ActiveRecord::Migration[8.1]
  def up
    create_table :workspace_invitations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :invited_by, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.string :email, null: false
      t.string :role, null: false, default: "recruiter"
      t.string :status, null: false, default: "pending"
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.timestamps

      t.index %i[organization_id email], unique: true
      t.index %i[organization_id status]
    end

    execute <<~SQL
      ALTER TABLE workspace_invitations ENABLE ROW LEVEL SECURITY;
      ALTER TABLE workspace_invitations FORCE ROW LEVEL SECURITY;
      CREATE POLICY organization_isolation ON workspace_invitations
        USING (organization_id = current_setting('app.current_organization', true)::uuid)
        WITH CHECK (organization_id = current_setting('app.current_organization', true)::uuid);
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "rolling back tenant isolation is unsafe"
  end
end
