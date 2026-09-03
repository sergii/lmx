# frozen_string_literal: true

namespace :db do
  desc "Provision the restricted PostgreSQL runtime role (run as the schema owner)"
  task provision_runtime_role: :environment do
    connection = ActiveRecord::Base.connection
    runtime_role = ENV.fetch("POSTGRES_RUNTIME_USER", "lmx_app")
    runtime_password = ENV.fetch("POSTGRES_RUNTIME_PASSWORD")

    unless runtime_role.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
      abort "POSTGRES_RUNTIME_USER must be a simple PostgreSQL role name"
    end

    owner = connection.select_value("SELECT current_user")
    database = connection.select_value("SELECT current_database()")
    role = connection.quote_column_name(runtime_role)
    owner_role = connection.quote_column_name(owner)
    database_name = connection.quote_column_name(database)
    password = connection.quote(runtime_password)

    connection.execute(<<~SQL)
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = #{connection.quote(runtime_role)}) THEN
          CREATE ROLE #{role} LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
        END IF;
      END
      $$;
    SQL
    connection.execute("ALTER ROLE #{role} LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD #{password}")
    connection.execute("GRANT CONNECT ON DATABASE #{database_name} TO #{role}")
    connection.execute("GRANT USAGE ON SCHEMA public TO #{role}")
    connection.execute("GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO #{role}")
    connection.execute("GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO #{role}")
    connection.execute("ALTER DEFAULT PRIVILEGES FOR ROLE #{owner_role} IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO #{role}")
    connection.execute("ALTER DEFAULT PRIVILEGES FOR ROLE #{owner_role} IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO #{role}")

    attributes = connection.select_one(<<~SQL.squish)
      SELECT rolsuper, rolbypassrls
      FROM pg_roles
      WHERE rolname = #{connection.quote(runtime_role)}
    SQL

    abort "Runtime role must not be superuser or bypass RLS" if attributes.values_at("rolsuper", "rolbypassrls").any?

    puts "Provisioned restricted runtime role #{runtime_role.inspect} for #{database.inspect}."
  end
end
