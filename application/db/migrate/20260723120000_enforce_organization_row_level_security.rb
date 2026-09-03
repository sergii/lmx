# frozen_string_literal: true

class EnforceOrganizationRowLevelSecurity < ActiveRecord::Migration[8.1]
  ORGANIZATION_TABLES = %w[
    candidates
    client_companies
    projects
    jobs
    applications
    application_stage_events
    audit_events
  ].freeze

  def up
    ORGANIZATION_TABLES.each do |table|
      execute <<~SQL
        ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY;
        ALTER TABLE #{table} FORCE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS organization_isolation ON #{table};
        CREATE POLICY organization_isolation ON #{table}
          USING (organization_id = current_setting('app.current_organization', true)::uuid)
          WITH CHECK (organization_id = current_setting('app.current_organization', true)::uuid);
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "rolling back tenant isolation is unsafe"
  end
end
