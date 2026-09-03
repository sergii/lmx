-- Local development runtime role. Migrations use the POSTGRES_USER owner;
-- Rails connects as this non-superuser so RLS is exercised during development.
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'lmx_app') THEN
    CREATE ROLE lmx_app LOGIN PASSWORD 'lmx_development' NOSUPERUSER NOBYPASSRLS;
  END IF;
END $$;
GRANT CONNECT ON DATABASE lmx_development TO lmx_app;
GRANT USAGE ON SCHEMA public TO lmx_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO lmx_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO lmx_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO lmx_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO lmx_app;
