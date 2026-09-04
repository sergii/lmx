# Temporary helper for PR #60. GitHub Actions runs PostgreSQL 18 in a service
# container while the hosted runner currently ships an older psql client.
# Remove this task after db/structure.sql has been regenerated.

namespace :db do
  namespace :structure do
    task :load do
      abort "temp db:structure:load is CI-only" unless ENV["GITHUB_ACTIONS"] == "true"

      database = ENV.fetch("POSTGRES_TEST_DATABASE", "lmx_test")
      container_id = `docker ps --filter ancestor=postgres:18.4 --format '{{.ID}}'`.lines.first&.strip
      abort "PostgreSQL 18 service container not found" if container_id.nil? || container_id.empty?

      structure_path = Rails.root.join("db/structure.sql")
      File.open(structure_path, "r") do |structure|
        loaded = system(
          "docker", "exec", "-i", container_id,
          "psql", "--username=lmx", "--dbname=#{database}",
          in: structure
        )
        abort "Failed to load db/structure.sql with PostgreSQL 18 psql" unless loaded
      end
    end
  end
end
