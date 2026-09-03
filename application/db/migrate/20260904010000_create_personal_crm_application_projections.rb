# frozen_string_literal: true

class CreatePersonalCrmApplicationProjections < ActiveRecord::Migration[8.1]
  STAGES = %w[
    applying applied recruiter_contact screening interview offer rejected withdrawn archived
  ].freeze

  def up
    create_table :personal_crm_application_projections, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.uuid :organization_id, null: false
      t.string :application_id, null: false
      t.string :candidate_id, null: false
      t.string :job_opening_id, null: false
      t.string :via_posting_id
      t.string :stage, null: false
      t.datetime :started_at, null: false
      t.datetime :applied_at
      t.string :channel
      t.text :next_action
      t.datetime :next_action_at
      t.jsonb :metadata, null: false, default: {}
      t.string :last_event_id, null: false
      t.integer :stream_version, null: false
      t.timestamps
    end

    add_index :personal_crm_application_projections,
      %i[organization_id application_id], unique: true,
      name: "index_personal_crm_applications_on_workspace_application"
    add_index :personal_crm_application_projections,
      %i[organization_id candidate_id started_at],
      name: "index_personal_crm_applications_on_workspace_candidate"
    add_index :personal_crm_application_projections,
      %i[organization_id stage next_action_at],
      name: "index_personal_crm_applications_on_workspace_stage_action"
    add_check_constraint :personal_crm_application_projections,
      "stage IN (#{STAGES.map { connection.quote(_1) }.join(', ')})",
      name: "personal_crm_application_projection_stage_check"

    execute <<~SQL
      ALTER TABLE personal_crm_application_projections ENABLE ROW LEVEL SECURITY;
      ALTER TABLE personal_crm_application_projections FORCE ROW LEVEL SECURITY;
      CREATE POLICY organization_isolation ON personal_crm_application_projections
        USING (organization_id = current_setting('app.current_organization', true)::uuid)
        WITH CHECK (organization_id = current_setting('app.current_organization', true)::uuid);
    SQL
  end

  def down
    drop_table :personal_crm_application_projections
  end
end
