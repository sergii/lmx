# frozen_string_literal: true

class CreateInterviewAssessmentSpine < ActiveRecord::Migration[8.1]
  TENANT_TABLES = %i[interviews interview_assessments competencies competency_assessments evidences competency_assessment_evidences].freeze

  def up
    create_table :interviews, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :candidate, null: false, type: :uuid, foreign_key: true
      t.references :application, type: :uuid, foreign_key: true
      t.references :meeting, type: :uuid, foreign_key: true, index: false
      t.references :created_by, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.string :template_name
      t.string :language
      t.string :status, null: false, default: "completed"
      t.text :interviewer_notes
      t.text :transcript
      t.string :recording_url
      t.datetime :completed_at
      t.timestamps
    end
    add_index :interviews, %i[organization_id candidate_id status]
    add_index :interviews, %i[application_id status]
    add_index :interviews, :meeting_id, unique: true, where: "meeting_id IS NOT NULL"
    add_check_constraint :interviews, "status IN ('draft', 'completed', 'cancelled')", name: "interviews_status_check"

    create_table :interview_assessments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :interview, null: false, type: :uuid, foreign_key: true
      t.references :assessor, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "draft"
      t.string :overall_level
      t.integer :rating
      t.string :recommendation
      t.text :strong_sides
      t.text :improvement_areas
      t.text :overall_comments
      t.timestamps
    end
    add_index :interview_assessments, %i[interview_id assessor_id], unique: true
    add_index :interview_assessments, %i[organization_id status]
    add_check_constraint :interview_assessments, "status IN ('draft', 'submitted', 'reviewed', 'approved')", name: "interview_assessments_status_check"
    add_check_constraint :interview_assessments, "rating IS NULL OR rating BETWEEN 1 AND 5", name: "interview_assessments_rating_check"

    create_table :competencies, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.timestamps
    end
    add_index :competencies, %i[organization_id name], unique: true

    create_table :competency_assessments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :interview_assessment, null: false, type: :uuid, foreign_key: true
      t.references :competency, null: false, type: :uuid, foreign_key: true
      t.string :status, null: false, default: "not_assessed"
      t.string :ai_suggested_level
      t.text :ai_suggested_comment
      t.string :manual_level
      t.text :manual_comment
      t.string :final_level
      t.text :final_comment
      t.decimal :confidence, precision: 4, scale: 3
      t.timestamps
    end
    add_index :competency_assessments, %i[interview_assessment_id competency_id], unique: true, name: "index_competency_assessments_on_assessment_and_competency"
    add_check_constraint :competency_assessments, "status IN ('not_assessed', 'insufficient_evidence', 'weak', 'demonstrated')", name: "competency_assessments_status_check"
    add_check_constraint :competency_assessments, "confidence IS NULL OR (confidence >= 0 AND confidence <= 1)", name: "competency_assessments_confidence_check"

    create_table :evidences, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :interview, null: false, type: :uuid, foreign_key: true
      t.string :source_type, null: false
      t.string :source_reference
      t.text :claim, null: false
      t.decimal :confidence, precision: 4, scale: 3
      t.timestamps
    end
    add_index :evidences, %i[interview_id source_type]
    add_check_constraint :evidences, "source_type IN ('transcript', 'interviewer_note', 'resume', 'live_coding', 'take_home_assignment')", name: "evidences_source_type_check"
    add_check_constraint :evidences, "confidence IS NULL OR (confidence >= 0 AND confidence <= 1)", name: "evidences_confidence_check"

    create_table :competency_assessment_evidences, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :competency_assessment, null: false, type: :uuid, foreign_key: true
      t.references :evidence, null: false, type: :uuid, foreign_key: true
      t.timestamps
    end
    add_index :competency_assessment_evidences, %i[competency_assessment_id evidence_id], unique: true, name: "index_competency_assessment_evidence_uniqueness"

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

  def down
    raise ActiveRecord::IrreversibleMigration, "rolling back interview assessment tenant isolation is unsafe"
  end
end
