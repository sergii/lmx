# frozen_string_literal: true

class CreatePersonalCrmOpportunityWorkflow < ActiveRecord::Migration[8.1]
  TABLES = %i[personal_crm_opportunity_dispositions personal_crm_applications].freeze

  def up
    create_table :personal_crm_opportunity_dispositions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.uuid :organization_id, null: false
      t.string :candidate_id, null: false
      t.string :job_opening_id, null: false
      t.string :state, null: false
      t.string :latest_application_id
      t.datetime :changed_at, null: false
      t.timestamps
    end

    add_index :personal_crm_opportunity_dispositions,
      %i[organization_id candidate_id job_opening_id], unique: true,
      name: "index_personal_crm_dispositions_on_workspace_candidate_opening"
    add_index :personal_crm_opportunity_dispositions, %i[organization_id id], unique: true,
      name: "index_personal_crm_dispositions_on_workspace_id"
    add_check_constraint :personal_crm_opportunity_dispositions,
      "state IN ('saved', 'ignored', 'applied')",
      name: "personal_crm_disposition_state"

    create_table :personal_crm_applications, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.uuid :organization_id, null: false
      t.string :candidate_id, null: false
      t.string :job_opening_id, null: false
      t.string :via_posting_id
      t.integer :attempt_number, null: false
      t.datetime :applied_at, null: false
      t.string :current_stage, null: false, default: "applied"
      t.string :channel
      t.text :next_action
      t.datetime :next_action_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :personal_crm_applications,
      %i[organization_id candidate_id job_opening_id attempt_number], unique: true,
      name: "index_personal_crm_applications_on_attempt"
    add_index :personal_crm_applications, %i[organization_id candidate_id job_opening_id applied_at],
      name: "index_personal_crm_applications_on_candidate_opening_time"
    add_index :personal_crm_applications, %i[organization_id id], unique: true,
      name: "index_personal_crm_applications_on_workspace_id"
    add_check_constraint :personal_crm_applications, "attempt_number > 0",
      name: "personal_crm_application_attempt_number"

    TABLES.each do |table|
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
    drop_table :personal_crm_applications
    drop_table :personal_crm_opportunity_dispositions
  end
end
