# frozen_string_literal: true

require "rails_helper"
require "pg"

RSpec.describe "Talent Profile row-level security", type: :model do
  RUNTIME_ROLE = ENV.fetch("POSTGRES_RLS_TEST_USER", "lmx_rls_test")
  RUNTIME_PASSWORD = ENV.fetch("POSTGRES_RLS_TEST_PASSWORD", "lmx_rls_test")
  TABLES = %w[candidate_evidences candidate_profile_versions candidate_profile_version_evidences].freeze

  before(:context) do
    provision_runtime_role!
  end

  before do
    @owner_connection = PG.connect(**connection_options)
    @runtime_connection = PG.connect(**connection_options.merge(user: RUNTIME_ROLE, password: RUNTIME_PASSWORD))
    @workspace_a_id = SecureRandom.uuid
    @workspace_b_id = SecureRandom.uuid
    @candidate_a_id = SecureRandom.uuid
    @candidate_b_id = SecureRandom.uuid
    @version_a_id = SecureRandom.uuid
    @version_b_id = SecureRandom.uuid

    create_workspace(@workspace_a_id, "Talent RLS A")
    create_workspace(@workspace_b_id, "Talent RLS B")
    create_candidate(@candidate_a_id, @workspace_a_id, "Allowed")
    create_candidate(@candidate_b_id, @workspace_b_id, "Hidden")
    create_profile_version(@version_a_id, @workspace_a_id, @candidate_a_id)
    create_profile_version(@version_b_id, @workspace_b_id, @candidate_b_id)
  end

  after do
    @runtime_connection&.close
    @owner_connection&.exec_params(
      "DELETE FROM candidate_profile_versions WHERE id = ANY($1::uuid[])",
      [ "{#{@version_a_id},#{@version_b_id}}" ]
    )
    @owner_connection&.exec_params(
      "DELETE FROM candidates WHERE id = ANY($1::uuid[])",
      [ "{#{@candidate_a_id},#{@candidate_b_id}}" ]
    )
    @owner_connection&.exec_params(
      "DELETE FROM organizations WHERE id = ANY($1::uuid[])",
      [ "{#{@workspace_a_id},#{@workspace_b_id}}" ]
    )
    @owner_connection&.close
  end

  it "enables and forces RLS on every Talent Profile tenant table" do
    rows = @owner_connection.exec(<<~SQL).to_a.index_by { _1.fetch("relname") }
      SELECT relname, relrowsecurity, relforcerowsecurity
      FROM pg_class
      WHERE relname IN ('candidate_evidences', 'candidate_profile_versions', 'candidate_profile_version_evidences')
    SQL

    expect(rows.keys).to contain_exactly(*TABLES)
    rows.each_value do |row|
      expect(row).to include("relrowsecurity" => "t", "relforcerowsecurity" => "t")
    end
  end

  it "fails closed without workspace context and exposes only the selected workspace" do
    expect(profile_version_ids).to be_empty

    @runtime_connection.exec_params(
      "SELECT set_config('app.current_organization', $1, false)",
      [ @workspace_a_id ]
    )

    expect(profile_version_ids).to contain_exactly(@version_a_id)
    expect(profile_version_ids).not_to include(@version_b_id)
  end

  it "rejects cross-workspace writes at the database boundary" do
    @runtime_connection.exec_params(
      "SELECT set_config('app.current_organization', $1, false)",
      [ @workspace_a_id ]
    )

    expect do
      @runtime_connection.exec_params(<<~SQL, [ SecureRandom.uuid, @workspace_b_id, @candidate_b_id ])
        INSERT INTO candidate_profile_versions
          (id, organization_id, candidate_id, version_number, schema_version, profile_data, content_digest, origin, created_at)
        VALUES
          ($1, $2, $3, 2, 1, '{}'::jsonb, '#{'0' * 64}', 'manual', CURRENT_TIMESTAMP)
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
    @owner_connection.exec_params(<<~SQL, [ id, name, "talent-rls-#{id.delete('-')}" ])
      INSERT INTO organizations (id, name, slug, created_at, updated_at)
      VALUES ($1, $2, $3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end

  def create_candidate(id, workspace_id, first_name)
    @owner_connection.exec_params(<<~SQL, [ id, workspace_id, first_name ])
      INSERT INTO candidates (id, organization_id, first_name, last_name, consent_status, created_at, updated_at)
      VALUES ($1, $2, $3, 'Candidate', 'unknown', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end

  def create_profile_version(id, workspace_id, candidate_id)
    @owner_connection.exec_params(<<~SQL, [ id, workspace_id, candidate_id ])
      INSERT INTO candidate_profile_versions
        (id, organization_id, candidate_id, version_number, schema_version, profile_data, content_digest, origin, created_at)
      VALUES
        ($1, $2, $3, 1, 1, '{}'::jsonb, '#{'0' * 64}', 'manual', CURRENT_TIMESTAMP)
    SQL
  end

  def profile_version_ids
    @runtime_connection.exec("SELECT id FROM candidate_profile_versions ORDER BY id").map { _1.fetch("id") }
  end
end
