# Staging deployment

LMX staging is a real production-mode deployment used to prove the Phase 0 operational contract before production. Terraform owns provider-level infrastructure and the persistent Hetzner data volume. Kamal owns Docker, the PostgreSQL accessory, kamal-proxy, Rails deployment, application secrets, and rollback.

## Deployment boundary

The application image is published to GHCR and deployed over SSH with Kamal. `config/deploy.yml` intentionally requires an explicit destination so a bare `bin/kamal deploy` cannot accidentally target an implicit environment.

Staging-specific host, TLS hostname, MCP public resource binding, PostgreSQL accessory, and persistent bind mounts live in `application/config/deploy.staging.yml`. No real hostnames, IPs, tokens, or database passwords belong in Git.

Long-running Rails containers receive only restricted runtime database URLs. The PostgreSQL schema-owner password and migration URLs are not referenced by the long-running Rails environment. This preserves PostgreSQL RLS as an actual runtime boundary instead of letting the web process connect as a table owner.

## Persistent storage topology

Terraform creates and protects one Hetzner Cloud Volume. Its actual mount path is exported as `data_volume_mount_path` and is passed to Kamal as `LMX_STAGING_DATA_VOLUME_PATH`.

The staging host uses two directories on that volume:

```text
<LMX_STAGING_DATA_VOLUME_PATH>/
  postgres/   -> /var/lib/postgresql
  storage/    -> /rails/storage
```

PostgreSQL 18 deliberately mounts the host directory at `/var/lib/postgresql`, not `/var/lib/postgresql/data`. PostgreSQL 18 uses a versioned `PGDATA` below that mount.

Before the first container boot, run `bin/prepare-staging-host`. It refuses unexpected mount paths, verifies that the Terraform-created Hetzner volume is actually mounted, creates the two directories, and assigns `/rails/storage` to the Rails uid/gid 1000.

The server is disposable. The Hetzner volume is the durable boundary.

## PostgreSQL accessory

Kamal runs `postgres:18.4` as the `lmx-staging-db` accessory on the same `kamal` Docker network as Rails.

The accessory:

- initializes `lmx_primary` through `POSTGRES_DB`
- initializes `lmx_cache`, `lmx_queue`, and `lmx_cable` through `config/postgres/init-lmx-databases.sql`
- uses `lmx_owner` as the schema-owner role
- uses `POSTGRES_OWNER_PASSWORD` only as an accessory secret
- persists all PostgreSQL data under `<LMX_STAGING_DATA_VOLUME_PATH>/postgres`
- publishes PostgreSQL only on host loopback as `127.0.0.1:5432`

The Rails runtime URLs should address the accessory by its Docker-network service name:

```text
postgresql://lmx_app:<runtime-password>@lmx-staging-db:5432/lmx_primary
postgresql://lmx_app:<runtime-password>@lmx-staging-db:5432/lmx_cache
postgresql://lmx_app:<runtime-password>@lmx-staging-db:5432/lmx_queue
postgresql://lmx_app:<runtime-password>@lmx-staging-db:5432/lmx_cable
```

Do not expose port 5432 publicly.

## Required operator inputs

Export these values in the shell that performs the deployment:

```text
LMX_STAGING_HOST
LMX_STAGING_HOSTNAME
LMX_STAGING_DATA_VOLUME_PATH
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
POSTGRES_OWNER_PASSWORD
POSTGRES_RUNTIME_PASSWORD
LMX_PHASE0_WORKSPACE_ID
TELEGRAM_BOT_TOKEN
TELEGRAM_CHAT_ID
OTEL_EXPORTER_OTLP_ENDPOINT
OTEL_EXPORTER_OTLP_HEADERS
LMX_MCP_OAUTH_AUTHORIZATION_SERVERS
LMX_MCP_OAUTH_SCOPES
LMX_MCP_OAUTH_INTROSPECTION_ENDPOINT
LMX_MCP_OAUTH_INTROSPECTION_CLIENT_ID
LMX_MCP_OAUTH_INTROSPECTION_CLIENT_SECRET
```

`KAMAL_REGISTRY_USERNAME` is optional and defaults to `sergii`.

Obtain the two Terraform-derived staging values instead of typing them manually:

```bash
export LMX_STAGING_HOST="$(terraform -chdir=infra/terraform/environments/staging output -raw staging_ipv4)"
export LMX_STAGING_DATA_VOLUME_PATH="$(terraform -chdir=infra/terraform/environments/staging output -raw data_volume_mount_path)"
```

The four `*_MIGRATION_URL` values must authenticate as `lmx_owner`. The four runtime URLs must authenticate with the restricted runtime role, normally `lmx_app`.

For MCP staging, `LMX_MCP_OAUTH_AUTHORIZATION_SERVERS` must contain exactly one issuer because the current introspection verifier is issuer-bound. `LMX_MCP_OAUTH_SCOPES` must be the explicit set of LMX MCP capabilities that the authorization server may issue for this resource. The staging destination derives these public values from the hostname:

```text
LMX_MCP_HTTP_ALLOWED_HOSTS=<LMX_STAGING_HOSTNAME>
LMX_MCP_OAUTH_RESOURCE=https://<LMX_STAGING_HOSTNAME>/mcp
LMX_MCP_OAUTH_RESOURCE_NAME=LMX MCP staging
```

Do not set `LMX_MCP_HTTP_ALLOWED_ORIGINS` preemptively for a hosted server-to-server client. If a real client sends an `Origin` header, record the observed value first and then add the narrowest explicit allowlist required by the client.

## Infrastructure prerequisites

Before the first deployment:

1. Terraform staging apply is complete and remote state is healthy.
2. `LMX_STAGING_HOSTNAME` resolves to `LMX_STAGING_HOST`.
3. The Hetzner data volume is attached and mounted at `LMX_STAGING_DATA_VOLUME_PATH`.
4. SSH access to the host works for the Kamal operator.
5. Ports 80 and 443 are reachable so kamal-proxy can terminate TLS.
6. GHCR credentials can push `ghcr.io/sergii/lmx` and the staging host can pull it.
7. The Telegram bot/chat and OTLP endpoint are staging-safe destinations.
8. The OAuth authorization server can issue an access token whose resource audience is exactly `https://<LMX_STAGING_HOSTNAME>/mcp` and whose identity is introspectable by the configured LMX client credentials.

## Validate configuration

From `application/`:

```bash
bin/kamal config -d staging
```

Kamal redacts referenced secrets in this output. Do not use commands that print resolved secrets in shared logs.

Before deploying MCP acceptance changes, confirm the rendered configuration contains the expected public resource, host, bind mounts, and `lmx-staging-db` accessory while secret values remain secret-backed.

## First database boot

Do not use `kamal setup` for the first staging boot. `kamal setup` boots accessories and then immediately deploys the app, but LMX must prepare all Rails schemas and the restricted runtime role between those two steps.

Prepare the persistent host directories first:

```bash
bin/prepare-staging-host
```

Bootstrap Docker:

```bash
bin/kamal server bootstrap -d staging
```

Boot PostgreSQL:

```bash
bin/kamal accessory boot db -d staging
```

The PostgreSQL port is available only on the remote host loopback. Open an SSH tunnel from the trusted migration machine:

```bash
ssh -o ExitOnForwardFailure=yes \
  -N \
  -L 15432:127.0.0.1:5432 \
  "root@${LMX_STAGING_HOST}"
```

Point the four migration URLs at `127.0.0.1:15432`, using the `lmx_owner` password, then in another shell run from `application/`:

```bash
RAILS_ENV=production bin/prepare-database
bin/provision-runtime-databases
```

`bin/provision-runtime-databases` invokes `db:provision_runtime_role` once per database. The runtime role is created with `NOSUPERUSER` and `NOBYPASSRLS`, then receives only the table, sequence, schema, and connection privileges required by the application.

After the schemas and runtime grants exist, deploy the application:

```bash
bin/kamal deploy -d staging
```

This ordering keeps the owner credentials outside long-running Rails containers and prevents Solid Queue or another boot-time database consumer from racing an empty schema.

## Subsequent releases

The database accessory persists independently from application deploys. It is not rebooted by normal `kamal deploy` commands.

For a release containing database changes:

1. open the SSH database tunnel
2. run `RAILS_ENV=production bin/prepare-database`
3. run `bin/provision-runtime-databases` when grants may need refreshing
4. run `bin/kamal deploy -d staging`

Migrations must remain backward compatible with the currently running version. Do not hide schema-owner credentials in a long-running app role merely to automate migrations. The next deployment-automation slice may wrap this exact sequence in GitHub Actions with a short-lived SSH tunnel.

## MCP live acceptance

Issue #66 is complete only after a real hosted ChatGPT/OpenAI MCP client reaches the staging endpoint. A green deploy or the local regression fixture alone is not enough.

First verify RFC 9728 protected-resource metadata from outside the staging host:

```bash
curl --fail-with-body \
  "https://${LMX_STAGING_HOSTNAME}/.well-known/oauth-protected-resource/mcp"
```

The response must identify the exact resource:

```text
https://<LMX_STAGING_HOSTNAME>/mcp
```

Then configure the hosted MCP client with:

```text
server_url = https://<LMX_STAGING_HOSTNAME>/mcp
```

and an OAuth access token issued for that resource. Complete first-contact pairing through the LMX browser flow if the verified `(issuer, subject, client_id)` identity does not yet have a persisted local grant.

The live proof must verify all of the following:

1. `initialize`
2. `notifications/initialized`
3. `tools/list`
4. one read `tools/call`, preferably `openings.search`
5. one additive write with a fresh explicit `idempotencyKey`
6. retry of the exact same write with the same key without a duplicate domain mutation
7. an invalid or unauthorized token fails closed without exposing workspace, principal, or capability data

Capture a sanitized version of the observed request shape, protocol header behavior, relevant response headers, and any client-specific quirks. Never capture bearer tokens, OAuth client secrets, raw session cookies, or private candidate data. Update `application/packs/integration/OPENAI_MCP.md` and the compatibility regression if live behavior differs from the current fixture.

## Phase 0 operational proof

A successful HTTP deploy is not the Phase 0 gate. Let the recurring collectors run long enough to establish source health, then execute the read-only readiness probe inside the live staging container:

```bash
bin/kamal phase0 -d staging
```

The result must report `status: ready`. The check proves production runtime environment, database connectivity/migrations, workspace resolution, forced RLS, recurring acquisition jobs, fresh successful source runs, Telegram reachability, OpenTelemetry configuration, and replayable raw payloads.

The active Phase 0 acquisition set is DOU, Djinni, Work.ua, Robota.ua, and RemoteOK. A source with no successful persisted raw payload cannot pass readiness even if the web process itself is healthy.

## Failure handling

Do not weaken the readiness check to make staging green. A failed source, missing replay payload, broken Telegram destination, missing OTLP exporter, pending migration, incorrect RLS policy, broken OAuth verifier, unmounted data volume, or unhealthy PostgreSQL accessory is a deployment finding to fix.

If application deployment fails after a backward-compatible migration, fix or roll back the application image with Kamal. Avoid destructive schema rollback while an older application version may still be running.
