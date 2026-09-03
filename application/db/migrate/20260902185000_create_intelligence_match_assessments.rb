# frozen_string_literal: true

class CreateIntelligenceMatchAssessments < ActiveRecord::Migration[8.1]
  def up
    create_table :intelligence_match_assessments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.uuid :organization_id, null: false
      t.string :candidate_id, null: false
      t.string :candidate_profile_version_id, null: false
      t.string :candidate_profile_content_digest, null: false
      t.string :job_opening_id, null: false
      t.datetime :opening_evidence_cutoff, null: false
      t.jsonb :opening_snapshot, null: false, default: {}
      t.integer :version_number, null: false
      t.decimal :opportunity_score, precision: 12, scale: 4
      t.decimal :action_priority, precision: 12, scale: 4
      t.jsonb :score_details, null: false, default: {}
      t.jsonb :strengths, null: false, default: []
      t.jsonb :gaps, null: false, default: []
      t.jsonb :risks, null: false, default: []
      t.text :recommendation
      t.jsonb :interview_angles, null: false, default: []
      t.jsonb :evidence_references, null: false, default: []
      t.string :scoring_policy_version, null: false
      t.string :processor_kind
      t.string :processor_key
      t.string :processor_version
      t.string :processor_model_name
      t.string :model_version
      t.datetime :generated_at, null: false
      t.datetime :created_at, null: false
    end

    add_index :intelligence_match_assessments,
      %i[organization_id candidate_id job_opening_id version_number], unique: true,
      name: "index_match_assessments_on_workspace_candidate_opening_version"
    add_index :intelligence_match_assessments,
      %i[organization_id candidate_id job_opening_id created_at],
      name: "index_match_assessments_on_workspace_candidate_opening_created"
    add_index :intelligence_match_assessments, %i[organization_id id], unique: true,
      name: "index_match_assessments_on_workspace_id"

    execute <<~SQL
      ALTER TABLE intelligence_match_assessments ENABLE ROW LEVEL SECURITY;
      ALTER TABLE intelligence_match_assessments FORCE ROW LEVEL SECURITY;
      CREATE POLICY organization_isolation ON intelligence_match_assessments
        USING (organization_id = current_setting('app.current_organization', true)::uuid)
        WITH CHECK (organization_id = current_setting('app.current_organization', true)::uuid);
    SQL
  end

  def down
    drop_table :intelligence_match_assessments
  end
end
