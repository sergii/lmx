# frozen_string_literal: true

require "rails_helper"
require "pg"

RSpec.describe "PostgreSQL row-level security", type: :model do
  RUNTIME_ROLE = ENV.fetch("POSTGRES_RLS_TEST_USER", "lmx_rls_test")
  RUNTIME_PASSWORD = ENV.fetch("POSTGRES_RLS_TEST_PASSWORD", "lmx_rls_test")

  before(:context) do
    provision_runtime_role!
  end

  before do
    @owner_connection = connect_as_owner
    @runtime_connection = connect_as_runtime
    @organization_a_id = SecureRandom.uuid
    @organization_b_id = SecureRandom.uuid
    @candidate_a_id = SecureRandom.uuid
    @candidate_b_id = SecureRandom.uuid
    @interviewer_a_id = SecureRandom.uuid
    @interviewer_b_id = SecureRandom.uuid
    @interview_a_id = SecureRandom.uuid
    @interview_b_id = SecureRandom.uuid

    create_organization(@organization_a_id, "RLS test A")
    create_organization(@organization_b_id, "RLS test B")
    create_user(@interviewer_a_id, "rls-a-#{@interviewer_a_id}@example.com")
    create_user(@interviewer_b_id, "rls-b-#{@interviewer_b_id}@example.com")
    create_candidate(@candidate_a_id, @organization_a_id, "Allowed")
    create_candidate(@candidate_b_id, @organization_b_id, "Forbidden")
    create_interview(@interview_a_id, @organization_a_id, @candidate_a_id, @interviewer_a_id)
    create_interview(@interview_b_id, @organization_b_id, @candidate_b_id, @interviewer_b_id)
  end

  after do
    @runtime_connection&.close
    @owner_connection&.exec_params("DELETE FROM interviews WHERE id = ANY($1::uuid[])", [ "{#{@interview_a_id},#{@interview_b_id}}" ])
    @owner_connection&.exec_params("DELETE FROM candidates WHERE organization_id = ANY($1::uuid[])", [ "{#{@organization_a_id},#{@organization_b_id}}" ])
    @owner_connection&.exec_params("DELETE FROM organizations WHERE id = ANY($1::uuid[])", [ "{#{@organization_a_id},#{@organization_b_id}}" ])
    @owner_connection&.exec_params("DELETE FROM users WHERE id = ANY($1::uuid[])", [ "{#{@interviewer_a_id},#{@interviewer_b_id}}" ])
    @owner_connection&.close
  end

  it "uses a non-superuser runtime role without RLS bypass" do
    attributes = @runtime_connection.exec(<<~SQL).first
      SELECT r.rolsuper, r.rolbypassrls
      FROM pg_roles r
      WHERE r.rolname = current_user
    SQL

    expect(attributes).to include("rolsuper" => "f", "rolbypassrls" => "f")
  end

  it "fails closed without tenant context and exposes only the selected tenant with context" do
    expect(candidate_ids).to be_empty
    set_organization(@organization_a_id)
    expect(candidate_ids).to contain_exactly(@candidate_a_id)
    expect(candidate_ids).not_to include(@candidate_b_id)
  end

  it "rejects writes for a different tenant at the database boundary" do
    set_organization(@organization_a_id)

    expect do
      @runtime_connection.exec_params(<<~SQL, [ SecureRandom.uuid, @organization_b_id ])
        INSERT INTO candidates (id, organization_id, first_name, last_name, consent_status, created_at, updated_at)
        VALUES ($1, $2, 'Blocked', 'Write', 'unknown', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL
    end.to raise_error(PG::InsufficientPrivilege, /row-level security policy/)
  end

  it "fails closed for interview records and exposes only the selected tenant's interview" do
    expect(interview_ids).to be_empty
    set_organization(@organization_a_id)
    expect(interview_ids).to contain_exactly(@interview_a_id)
    expect(interview_ids).not_to include(@interview_b_id)
  end

  it "forces row-level security on job briefs and public posting links" do
    rows = @owner_connection.exec(<<~SQL).to_a.index_by { |row| row.fetch("relname") }
      SELECT relname, relrowsecurity, relforcerowsecurity
      FROM pg_class
      WHERE relname IN ('sourcing_briefs', 'job_postings')
    SQL

    expect(rows).to include("sourcing_briefs", "job_postings")
    rows.each_value do |row|
      expect(row).to include("relrowsecurity" => "t", "relforcerowsecurity" => "t")
    end
  end

  private

  def provision_runtime_role!
    connection = ActiveRecord::Base.connection
    role = connection.quote_column_name(RUNTIME_ROLE)
    password = connection.quote(RUNTIME_PASSWORD)

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
    connection.execute("GRANT CONNECT ON DATABASE #{quote_database_name} TO #{role}")
    connection.execute("GRANT USAGE ON SCHEMA public TO #{role}")
    connection.execute("GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO #{role}")
    connection.execute("GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO #{role}")
  end

  def connect_as_owner
    PG.connect(**owner_connection_options)
  end

  def connect_as_runtime
    PG.connect(**owner_connection_options.merge(user: RUNTIME_ROLE, password: RUNTIME_PASSWORD))
  end

  def owner_connection_options
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    {
      host: config.fetch(:host),
      port: config.fetch(:port),
      dbname: config.fetch(:database),
      user: config.fetch(:username),
      password: config.fetch(:password)
    }
  end

  def quote_database_name
    ActiveRecord::Base.connection.quote_column_name(owner_connection_options.fetch(:dbname))
  end

  def create_organization(id, name)
    @owner_connection.exec_params(<<~SQL, [ id, name, "rls-#{id.delete('-')}" ])
      INSERT INTO organizations (id, name, slug, created_at, updated_at)
      VALUES ($1, $2, $3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end

  def create_candidate(id, organization_id, first_name)
    @owner_connection.exec_params(<<~SQL, [ id, organization_id, first_name ])
      INSERT INTO candidates (id, organization_id, first_name, last_name, consent_status, created_at, updated_at)
      VALUES ($1, $2, $3, 'Candidate', 'unknown', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end

  def create_user(id, email)
    @owner_connection.exec_params(<<~SQL, [ id, email ])
      INSERT INTO users (id, name, email, password_digest, verified, created_at, updated_at)
      VALUES ($1, 'RLS interviewer', $2, 'not-a-real-password', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end

  def create_interview(id, organization_id, candidate_id, created_by_id)
    @owner_connection.exec_params(<<~SQL, [ id, organization_id, candidate_id, created_by_id ])
      INSERT INTO interviews (id, organization_id, candidate_id, created_by_id, status, created_at, updated_at)
      VALUES ($1, $2, $3, $4, 'completed', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end

  def set_organization(organization_id)
    @runtime_connection.exec_params("SELECT set_config('app.current_organization', $1, false)", [ organization_id ])
  end

  def candidate_ids
    @runtime_connection.exec("SELECT id FROM candidates ORDER BY id").map { |row| row.fetch("id") }
  end

  def interview_ids
    @runtime_connection.exec("SELECT id FROM interviews ORDER BY id").map { |row| row.fetch("id") }
  end
end
