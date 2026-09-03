# Staging deployment

LMX staging is a real production-mode deployment used to prove the Phase 0 operational contract before production. Kamal uses the canonical Rails application under `application/` and the `staging` destination.

## Deployment boundary

The application image is published to GHCR and deployed over SSH with Kamal. `config/deploy.yml` intentionally requires an explicit destination so a bare `bin/kamal deploy` cannot accidentally target an implicit environment.

Staging-specific host, TLS hostname, and persistent storage live in `application/config/deploy.staging.yml`. No real hostnames, IPs, tokens, or database passwords belong in Git.

Long-running Rails containers receive only restricted runtime database URLs. Schema-owner credentials are used only by the explicit database preparation commands below. This preserves PostgreSQL RLS as an actual runtime boundary instead of letting the web process connect as a table owner.

## Required operator inputs

Export these values in the shell that performs the deployment:

```text
LMX_STAGING_HOST
LMX_STAGING_HOSTNAME
KAMAL_REGISTRY_PASSWORD
RAILS_MASTER_KEY
DATABASE_URL
CACHE_DATABASE_URL
QUEUE_DATABASE_URL
CABLE_DATABASE_URL
DATABASE_MIGRATION_URL
CACHE_DATABASE_MIGRATION_URL
QUEUE_DATABASE_MIGRATION_URL
CABLE_DATABASE_MIGRATION_URL
POSTGRES_RUNTIME_PASSWORD
LMX_PHASE0_WORKSPACE_ID
TELEGRAM_BOT_TOKEN
TELEGRAM_CHAT_ID
OTEL_EXPORTER_OTLP_ENDPOINT
OTEL_EXPORTER_OTLP_HEADERS
```

`KAMAL_REGISTRY_USERNAME` is optional and defaults to `sergii`.

The four `*_MIGRATION_URL` values must authenticate as schema owners. The four runtime URLs must authenticate with the restricted runtime role, normally `lmx_app`. They may point to four databases on one PostgreSQL server.

## Infrastructure prerequisites

Before the first deployment:

1. `LMX_STAGING_HOSTNAME` resolves to `LMX_STAGING_HOST`.
2. SSH access to the host works for the Kamal operator.
3. Ports 80 and 443 are reachable so kamal-proxy can terminate TLS.
4. PostgreSQL is reachable from the machine that performs the initial database preparation, or the commands below are executed from another trusted network location that can reach it.
5. GHCR credentials can push `ghcr.io/sergii/lmx` and the staging host can pull it.
6. The Telegram bot/chat and OTLP endpoint are staging-safe destinations.

## Validate configuration

From `application/`:

```bash
bin/kamal config -d staging
```

Kamal redacts referenced secrets in this output. Do not use `bin/kamal secrets print` in shared logs.

## Prepare production-mode databases

The Rails image deliberately does not migrate on container startup. Before the first staging boot, prepare all four databases with owner credentials:

```bash
RAILS_ENV=production bin/prepare-database
```

Then provision the restricted runtime role in each prepared database:

```bash
bin/provision-runtime-databases
```

`bin/provision-runtime-databases` invokes `db:provision_runtime_role` once per database. The runtime role is created with `NOSUPERUSER` and `NOBYPASSRLS`, then receives only the table, sequence, schema, and connection privileges required by the application.

For later releases, migrations must remain backward compatible with the currently running version. Until the database network topology is fixed, database preparation remains an explicit release step rather than a hidden Kamal hook.

## First deploy

Bootstrap Docker and deploy the application:

```bash
bin/kamal setup -d staging
```

Subsequent releases use:

```bash
bin/kamal deploy -d staging
```

## Phase 0 operational proof

A successful HTTP deploy is not the Phase 0 gate. Let the recurring collectors run long enough to establish source health, then execute the read-only readiness probe inside the live staging container:

```bash
bin/kamal phase0 -d staging
```

The result must report `status: ready`. The check proves production runtime environment, database connectivity/migrations, workspace resolution, forced RLS, recurring acquisition jobs, fresh successful source runs, Telegram reachability, OpenTelemetry configuration, and replayable raw payloads.

The active Phase 0 acquisition set is DOU, Djinni, Work.ua, Robota.ua, and RemoteOK. A source with no successful persisted raw payload cannot pass readiness even if the web process itself is healthy.

## Failure handling

Do not weaken the readiness check to make staging green. A failed source, missing replay payload, broken Telegram destination, missing OTLP exporter, pending migration, or incorrect RLS policy is a deployment finding to fix.

If application deployment fails after a backward-compatible migration, fix or roll back the application image with Kamal. Avoid destructive schema rollback while an older application version may still be running.
