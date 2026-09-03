# frozen_string_literal: true

require "rails_helper"
require "pg"

RSpec.describe "Personal CRM application projection row-level security", type: :model do
  RUNTIME_ROLE = ENV.fetch("POSTGRES_RLS_TEST_USER", "lmx_rls_test")
  RUNTIME_PASSWORD = ENV.fetch("POSTGRES_RLS_TEST_PASSWORD", "lmx_rls_test")
  TABLE = "personal_crm_application_projections"

  before(:context) do
    provision_runtime_role!
  end

  before do
    @owner_connection = PG.connect(**connection_options)
    @runtime_connection = PG.connect(**connection_options.merge(user: RUNTIME_ROLE, password: RUNTIME_PASSWORD))
    @workspace_a_id = SecureRandom.uuid
    @workspace_b_id = SecureRandom.uuid
    @projection_a_id = SecureRandom.uuid
    @projection_b_id = SecureRandom.uuid

    create_workspace(@workspace_a_id, "Personal CRM RLS A")
    create_workspace(@workspace_b_id, "Personal CRM RLS B")
    create_projection(@projection_a_id, @workspace_a_id, "application_attempt_a")
    create_projection(@projection_b_id, @workspace_b_id, "application_attempt_b")
  end

  after do
    @runtime_connection&.close
    @owner_connection&.exec_params(
      "DELETE FROM personal_crm_application_projections WHERE id = ANY($1::uuid[])",
      [ "{#{@projection_a_id},#{@projection_b_id}}" ]
    )
    @owner_connection&.exec_params(
      "DELETE FROM organizations WHERE id = ANY($1::uuid[])",
      [ "{#{@workspace_a_id},#{@workspace_b_id}}" ]
    )
    @owner_connection&.close
  end

  it "enables and forces RLS on the projection table" do
    row = @owner_connection.exec_params(<<~SQL, [ TABLE ]).first
      SELECT relname, relrowsecurity, relforcerowsecurity
      FROM pg_class
      WHERE relname = $1
    SQL

    expect(row).to include(
      "relname" => TABLE,
      "relrowsecurity" => "t",
      "relforcerowsecurity" => "t"
    )
  end

  it "fails closed without workspace context and exposes only the selected workspace" do
    expect(projection_ids).to be_empty

    @runtime_connection.exec_params(
      "SELECT set_config('app.current_organization', $1, false)",
      [ @workspace_a_id ]
    )

    expect(projection_ids).to contain_exactly(@projection_a_id)
    expect(projection_ids).not_to include(@projection_b_id)
  end

  it "rejects cross-workspace writes at the database boundary" do
    @runtime_connection.exec_params(
      "SELECT set_config('app.current_organization', $1, false)",
      [ @workspace_a_id ]
    )

    expect do
      @runtime_connection.exec_params(<<~SQL, [ SecureRandom.uuid, @workspace_b_id ])
        INSERT INTO personal_crm_application_projections
          (id, organization_id, application_id, candidate_id, job_opening_id, stage,
           started_at, metadata, last_event_id, stream_version, created_at, updated_at)
        VALUES
          ($1, $2, 'application_attempt_cross', 'candidate_cross', 'job_opening_cross',
           'applying', CURRENT_TIMESTAMP, '{}'::jsonb, 'event_cross', 1,
           CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
    end.to raise_error(PG::InsufficientPrivilege, /row-level security policy/)
  end

  private

  def provision_runtime_role!
    connection = ActiveRecord::Base.connection
    role = connection.quote_column_name(RUNTIME_ROLE)
    password = connection.quote(RUNTIME_PASSWORD)
    database = connection.quote_column_name(connection_options.fetch(:dbname))

    connection.execute(<<~SQL)
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = #{connection.quote(RUNTIME_ROLE)}) THEN
          CREATE ROLE #{role} LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
        END IF;
      END
      $$;
    SQL
    connection.execute("ALTER ROLE #{role} LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD #{password}")
    connection.execute("GRANT CONNECT ON DATABASE #{database} TO #{role}")
    connection.execute("GRANT USAGE ON SCHEMA public TO #{role}")
    connection.execute("GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO #{role}")
  end

  def connection_options
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    {
      host: config.fetch(:host),
      port: config.fetch(:port),
      dbname: config.fetch(:database),
      user: config.fetch(:username),
      password: config.fetch(:password)
    }
  end

  def create_workspace(id, name)
    @owner_connection.exec_params(<<~SQL, [ id, name, "personal-crm-rls-#{id.delete('-')}" ])
      INSERT INTO organizations (id, name, slug, created_at, updated_at)
      VALUES ($1, $2, $3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end

  def create_projection(id, workspace_id, application_id)
    @owner_connection.exec_params(<<~SQL, [ id, workspace_id, application_id ])
      INSERT INTO personal_crm_application_projections
        (id, organization_id, application_id, candidate_id, job_opening_id, stage,
         started_at, metadata, last_event_id, stream_version, created_at, updated_at)
      VALUES
        ($1, $2, $3, 'candidate_test', 'job_opening_test', 'applying', CURRENT_TIMESTAMP,
         '{}'::jsonb, 'event_test', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end

  def projection_ids
    @runtime_connection.exec(
      "SELECT id FROM personal_crm_application_projections ORDER BY id"
    ).map { _1.fetch("id") }
  end
end
