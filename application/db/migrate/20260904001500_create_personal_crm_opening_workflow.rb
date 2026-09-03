# frozen_string_literal: true

class CreatePersonalCrmOpeningWorkflow < ActiveRecord::Migration[8.1]
  APPLICATION_STAGES = %w[
    applying applied recruiter_contact screening interview offer rejected withdrawn archived
  ].freeze

  def up
    create_table :personal_crm_opening_dispositions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.uuid :organization_id, null: false
      t.string :candidate_id, null: false
      t.string :job_opening_id, null: false
      t.string :state, null: false
      t.datetime :decided_at, null: false
      t.timestamps
    end

    add_index :personal_crm_opening_dispositions,
      %i[organization_id candidate_id job_opening_id], unique: true,
      name: "index_personal_crm_dispositions_on_workspace_candidate_opening"
    add_index :personal_crm_opening_dispositions, %i[organization_id state decided_at],
      name: "index_personal_crm_dispositions_on_workspace_state"
    add_check_constraint :personal_crm_opening_dispositions,
      "state IN ('saved', 'ignored')",
      name: "personal_crm_opening_dispositions_state_check"

    create_table :personal_crm_applications, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.uuid :organization_id, null: false
      t.string :candidate_id, null: false
      t.string :job_opening_id, null: false
      t.string :via_posting_id
      t.string :stage, null: false, default: "applying"
      t.datetime :started_at, null: false
      t.datetime :applied_at
      t.string :channel
      t.text :next_action
      t.datetime :next_action_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :personal_crm_applications,
      %i[organization_id candidate_id job_opening_id started_at],
      name: "index_personal_crm_applications_on_candidate_opening_started"
    add_index :personal_crm_applications,
      %i[organization_id stage next_action_at],
      name: "index_personal_crm_applications_on_workspace_stage_next_action"
    add_index :personal_crm_applications, %i[organization_id id], unique: true,
      name: "index_personal_crm_applications_on_workspace_id"
    add_check_constraint :personal_crm_applications,
      "stage IN (#{APPLICATION_STAGES.map { connection.quote(_1) }.join(', ')})",
      name: "personal_crm_applications_stage_check"

    execute <<~SQL
      ALTER TABLE personal_crm_opening_dispositions ENABLE ROW LEVEL SECURITY;
      ALTER TABLE personal_crm_opening_dispositions FORCE ROW LEVEL SECURITY;
      CREATE POLICY organization_isolation ON personal_crm_opening_dispositions
        USING (organization_id = current_setting('app.current_organization', true)::uuid)
        WITH CHECK (organization_id = current_setting('app.current_organization', true)::uuid);

      ALTER TABLE personal_crm_applications ENABLE ROW LEVEL SECURITY;
      ALTER TABLE personal_crm_applications FORCE ROW LEVEL SECURITY;
      CREATE POLICY organization_isolation ON personal_crm_applications
        USING (organization_id = current_setting('app.current_organization', true)::uuid)
        WITH CHECK (organization_id = current_setting('app.current_organization', true)::uuid);
    SQL
  end

  def down
    drop_table :personal_crm_applications
    drop_table :personal_crm_opening_dispositions
  end
end
