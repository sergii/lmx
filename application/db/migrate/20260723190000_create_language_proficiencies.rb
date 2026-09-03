# frozen_string_literal: true

class CreateLanguageProficiencies < ActiveRecord::Migration[8.1]
  LEGACY_ENGLISH_LEVELS = {
    "beginner" => "a1",
    "intermediate" => "b1",
    "upper_intermediate" => "b2",
    "advanced" => "c1",
    "native" => "c2"
  }.freeze

  def up
    create_table :language_proficiencies, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :candidate, null: false, type: :uuid, foreign_key: true
      t.string :language_code, null: false, limit: 2
      t.string :level, null: false, limit: 2
      t.timestamps
    end
    add_index :language_proficiencies, %i[candidate_id language_code], unique: true
    add_index :language_proficiencies, %i[organization_id language_code level]

    execute <<~SQL
      INSERT INTO language_proficiencies (id, organization_id, candidate_id, language_code, level, created_at, updated_at)
      SELECT uuidv7(), organization_id, id, 'en',
        CASE english_level
          WHEN 'beginner' THEN 'a1'
          WHEN 'intermediate' THEN 'b1'
          WHEN 'upper_intermediate' THEN 'b2'
          WHEN 'advanced' THEN 'c1'
          WHEN 'native' THEN 'c2'
        END,
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM candidates
      WHERE english_level IN ('beginner', 'intermediate', 'upper_intermediate', 'advanced', 'native');
    SQL

    execute <<~SQL
      ALTER TABLE language_proficiencies ENABLE ROW LEVEL SECURITY;
      ALTER TABLE language_proficiencies FORCE ROW LEVEL SECURITY;
      CREATE POLICY organization_isolation ON language_proficiencies
        USING (organization_id = current_setting('app.current_organization', true)::uuid)
        WITH CHECK (organization_id = current_setting('app.current_organization', true)::uuid);
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "rolling back tenant isolation is unsafe"
  end
end
