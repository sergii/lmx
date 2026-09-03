# frozen_string_literal: true

class CreateStaffingWorkflow < ActiveRecord::Migration[8.1]
  ORGANIZATION_TABLES = %w[client_companies projects jobs applications].freeze

  def change
    create_table :client_companies, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end
    add_index :client_companies, %i[organization_id name], unique: true

    create_table :projects, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :client_company, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end
    add_index :projects, %i[organization_id client_company_id name], unique: true, name: "index_projects_on_org_client_and_name"

    create_table :jobs, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.string :title, null: false
      t.string :seniority
      t.string :technology_stack
      t.string :status, null: false, default: "draft"
      t.timestamps
    end
    add_index :jobs, %i[organization_id project_id status]

    create_table :applications, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :candidate, type: :uuid, null: false, foreign_key: true
      t.references :job, type: :uuid, null: false, foreign_key: true
      t.references :sourced_by, foreign_key: { to_table: :users }
      t.string :stage, null: false, default: "sourced"
      t.timestamps
    end
    add_index :applications, %i[candidate_id job_id], unique: true
    add_index :applications, %i[organization_id job_id stage]

    ORGANIZATION_TABLES.each do |table|
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
