# frozen_string_literal: true

class EstablishTalentProfileCore < ActiveRecord::Migration[8.1]
  TENANT_TABLES = %i[
    candidate_evidences
    candidate_profile_versions
    candidate_profile_version_evidences
  ].freeze

  def up
    add_column :candidates, :linked_user_id, :uuid
    add_index :candidates, %i[organization_id id], unique: true, name: "index_candidates_on_workspace_id"
    add_index :candidates, %i[organization_id linked_user_id], unique: true,
      where: "linked_user_id IS NOT NULL", name: "index_candidates_on_workspace_linked_user"

    execute <<~SQL
      ALTER TABLE candidates
        ADD CONSTRAINT fk_candidates_linked_workspace_member
        FOREIGN KEY (linked_user_id, organization_id)
        REFERENCES memberships (user_id, organization_id);
    SQL

    create_table :candidate_evidences, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.uuid :candidate_id, null: false
      t.string :source_type, null: false
      t.text :source_reference
      t.text :claim, null: false
      t.decimal :confidence, precision: 4, scale: 3
      t.datetime :observed_at
      t.jsonb :provenance, null: false, default: {}
      t.timestamps
    end
    add_index :candidate_evidences, %i[organization_id candidate_id created_at],
      name: "index_candidate_evidences_on_workspace_candidate_created"
    add_index :candidate_evidences, %i[organization_id id], unique: true,
      name: "index_candidate_evidences_on_workspace_id"

    create_table :candidate_profile_versions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.uuid :candidate_id, null: false
      t.integer :version_number, null: false
      t.integer :schema_version, null: false, default: 1
      t.jsonb :profile_data, null: false, default: {}
      t.string :content_digest, null: false
      t.string :origin, null: false
      t.uuid :accepted_by_user_id
      t.datetime :accepted_at
      t.datetime :created_at, null: false
    end
    add_index :candidate_profile_versions, %i[candidate_id version_number], unique: true,
      name: "index_candidate_profile_versions_on_candidate_version"
    add_index :candidate_profile_versions, %i[organization_id candidate_id version_number],
      name: "index_candidate_profile_versions_on_workspace_candidate_version"
    add_index :candidate_profile_versions, %i[organization_id id], unique: true,
      name: "index_candidate_profile_versions_on_workspace_id"

    create_table :candidate_profile_version_evidences, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.uuid :candidate_profile_version_id, null: false
      t.uuid :candidate_evidence_id, null: false
      t.datetime :created_at, null: false
    end
    add_index :candidate_profile_version_evidences,
      %i[candidate_profile_version_id candidate_evidence_id], unique: true,
      name: "index_profile_version_evidences_on_version_evidence"
    add_index :candidate_profile_version_evidences,
      %i[organization_id candidate_profile_version_id],
      name: "index_profile_version_evidences_on_workspace_version"

    add_workspace_foreign_keys
    enable_workspace_rls
  end

  def down
    drop_table :candidate_profile_version_evidences
    drop_table :candidate_profile_versions
    drop_table :candidate_evidences

    execute "ALTER TABLE candidates DROP CONSTRAINT IF EXISTS fk_candidates_linked_workspace_member"
    remove_index :candidates, name: "index_candidates_on_workspace_linked_user"
    remove_index :candidates, name: "index_candidates_on_workspace_id"
    remove_column :candidates, :linked_user_id
  end

  private

  def add_workspace_foreign_keys
    execute <<~SQL
      ALTER TABLE candidate_profile_versions
        ADD CONSTRAINT fk_profile_versions_accepting_workspace_member
        FOREIGN KEY (accepted_by_user_id, organization_id)
        REFERENCES memberships (user_id, organization_id);

      ALTER TABLE candidate_evidences
        ADD CONSTRAINT fk_candidate_evidences_workspace_candidate
        FOREIGN KEY (organization_id, candidate_id)
        REFERENCES candidates (organization_id, id);

      ALTER TABLE candidate_profile_versions
        ADD CONSTRAINT fk_profile_versions_workspace_candidate
        FOREIGN KEY (organization_id, candidate_id)
        REFERENCES candidates (organization_id, id);

      ALTER TABLE candidate_profile_version_evidences
        ADD CONSTRAINT fk_profile_version_evidences_workspace_version
        FOREIGN KEY (organization_id, candidate_profile_version_id)
        REFERENCES candidate_profile_versions (organization_id, id);

      ALTER TABLE candidate_profile_version_evidences
        ADD CONSTRAINT fk_profile_version_evidences_workspace_evidence
        FOREIGN KEY (organization_id, candidate_evidence_id)
        REFERENCES candidate_evidences (organization_id, id);
    SQL
  end

  def enable_workspace_rls
    TENANT_TABLES.each do |table|
      execute <<~SQL
        ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY;
        ALTER TABLE #{table} FORCE ROW LEVEL SECURITY;
        CREATE POLICY organization_isolation ON #{table}
          USING (organization_id = current_setting('app.current_organization', true)::uuid)
          WITH CHECK (organization_id = current_setting('app.current_organization', true)::uuid);
      SQL
    end
  end
end
