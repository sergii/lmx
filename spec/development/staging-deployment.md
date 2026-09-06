# Staging deployment

LMX staging is a production-mode environment used to prove the Phase 0 operational contract before production.

The ownership boundary is intentional:

- Terraform owns the Hetzner server, firewall, SSH public key, and protected persistent volume.
- Kamal owns Docker, the `kamal` network, PostgreSQL accessory, kamal-proxy, Rails containers, and rollback.
- GitHub Actions orchestrates the two without giving application deployment permission to mutate cloud infrastructure.

## Persistent topology

Terraform exports the server address, public hostname, and Hetzner volume mount path. The server is disposable; the volume is durable.

```text
<LMX_STAGING_DATA_VOLUME_PATH>/
  postgres/   -> /var/lib/postgresql
  storage/    -> /rails/storage
```

PostgreSQL 18 uses `/var/lib/postgresql` as the persistent mount boundary. Rails runs with `/rails/storage` on the same protected staging volume.

The PostgreSQL accessory is `lmx-staging-db`, attached to the private `kamal` Docker network. Port 5432 is published only on host loopback:

```text
127.0.0.1:5432:5432
```

Long-running Rails containers connect through Docker DNS:

```text
postgresql://lmx_app:<runtime-password>@lmx-staging-db:5432/lmx_primary
postgresql://lmx_app:<runtime-password>@lmx-staging-db:5432/lmx_cache
postgresql://lmx_app:<runtime-password>@lmx-staging-db:5432/lmx_queue
postgresql://lmx_app:<runtime-password>@lmx-staging-db:5432/lmx_cable
```

Schema-owner migrations never use that runtime identity. GitHub Actions opens a short-lived SSH tunnel to host loopback and derives migration URLs on `127.0.0.1:15432` for `lmx_owner`.

## GitHub environments

The canonical automation uses two GitHub Environments.

`staging-infra` is the reviewed infrastructure-write boundary. It contains the Hetzner write token and Terraform state write credentials. Only the manually dispatched Terraform apply job uses it.

`staging` is the application-deployment boundary. It contains read-only Terraform state credentials, the staging SSH private key, and application secrets. It does not receive a Hetzner API token.

The complete variable/secret contract is documented in `infra/terraform/GITHUB_ACTIONS.md`.

## First infrastructure apply

Before deploying durable data, run the reviewed Terraform workflow once and prove remote state and locking:

```text
Actions -> Terraform -> Run workflow
  action = apply
  confirmation = apply-staging
```

The apply runs behind the `staging-infra` environment and publishes:

- `staging_ipv4`
- `staging_hostname`
- `data_volume_mount_path`

The hostname must resolve publicly to the staging server before Kamal requests TLS certificates.

## Canonical first deploy

Keep repository variable `LMX_STAGING_AUTO_DEPLOY=false` for the first deployment.

Run:

```text
Actions -> Deploy staging -> Run workflow
```

The workflow performs the complete first-boot sequence:

```text
read Terraform remote-state outputs
-> configure SSH
-> derive runtime and migration database URLs
-> bootstrap Docker if missing
-> verify the Hetzner volume mount
-> create the private kamal network if missing
-> boot/start postgres:18.4
-> wait for PostgreSQL readiness
-> run Rails migrations as lmx_owner through an SSH tunnel
-> create/update restricted lmx_app privileges
-> build/push/deploy Rails with Kamal
-> GET /up
-> verify MCP RFC 9728 protected-resource metadata
-> run Phase 0 source acceptance
-> run Phase 0 readiness
```

`application/bin/deploy-staging` contains the reusable host/database/Kamal part of this sequence. It is intentionally runnable outside GitHub Actions when the same environment variables and migration tunnel are supplied.

The workflow uses its short-lived GitHub token for GHCR. There is no long-lived staging GHCR password to provision.

## Hands-free deploys

After one complete manual deployment succeeds, set the repository variable:

```text
LMX_STAGING_AUTO_DEPLOY=true
```

From then on, a successful `CI` workflow caused by a `push` to `main` automatically starts the `Deploy staging` workflow for the exact tested commit.

The automatic trigger explicitly rejects pull-request workflow runs, even if a fork happens to use a branch named `main`. Infrastructure still remains manual/reviewed through `staging-infra`.

To temporarily stop automatic staging delivery, set `LMX_STAGING_AUTO_DEPLOY=false`. Manual deployment remains available.

## Database security boundary

The PostgreSQL accessory initializes four databases:

```text
lmx_primary
lmx_cache
lmx_queue
lmx_cable
```

`lmx_owner` owns schemas and runs migrations. `lmx_app` is the long-running runtime role.

`bin/provision-runtime-databases` creates/updates `lmx_app` as `NOSUPERUSER` and `NOBYPASSRLS` and grants only the schema/table/sequence/connect privileges required by Rails.

The workflow derives all eight database URLs from two secrets:

```text
POSTGRES_OWNER_PASSWORD
POSTGRES_RUNTIME_PASSWORD
```

No runtime or migration database URL needs to be stored in GitHub Secrets.

Migrations must remain backward compatible with the currently running version. A failed app deploy after a successful migration should be handled by fixing or rolling back the application image, not by destructively rolling back schema while an older container may still run.

## Local/manual fallback

For debugging, export the same public/runtime values and secrets expected by Kamal, open an SSH tunnel:

```bash
ssh -N \
  -L 15432:127.0.0.1:5432 \
  "root@${LMX_STAGING_HOST}"
```

Set the four runtime URLs to `lmx-staging-db:5432`, set the four migration URLs to `127.0.0.1:15432`, then run from `application/`:

```bash
bin/deploy-staging
```

Do not use `kamal setup` for the first LMX staging boot. LMX must establish the schemas and restricted runtime role between PostgreSQL initialization and application boot; `bin/deploy-staging` preserves that ordering.

## HTTP and MCP smoke checks

A successful Kamal command is not enough. The automated workflow verifies:

```text
https://<LMX_STAGING_HOSTNAME>/up
```

and RFC 9728 metadata at:

```text
https://<LMX_STAGING_HOSTNAME>/.well-known/oauth-protected-resource/mcp
```

The metadata resource must be exactly:

```text
https://<LMX_STAGING_HOSTNAME>/mcp
```

These checks prove public routing/TLS and the MCP protected-resource binding. They do not complete issue #66 by themselves.

## Live MCP acceptance

Issue #66 still requires a real hosted ChatGPT/OpenAI MCP client against staging. Verify:

1. `initialize`
2. `notifications/initialized`
3. `tools/list`
4. one read call, preferably `openings.search`
5. one additive write with a fresh `idempotencyKey`
6. exact retry with the same key and no duplicate mutation
7. invalid/unauthorized token fails closed

Capture only sanitized protocol shape and client quirks. Never capture bearer tokens, OAuth client secrets, raw session cookies, or private candidate data.

## Phase 0 operational gate

The deployment workflow runs:

```bash
bin/kamal phase0-accept -d staging
bin/kamal phase0 -d staging
```

Source acceptance proves real acquisition runs persist successful `SourceRun` records, observations, and replayable raw evidence. The readiness gate must then report `status: ready`.

The active source set is DOU, Djinni, Work.ua, Robota.ua, and RemoteOK. Source failure is an operational finding, not a reason to weaken the gate.

## Failure handling

Keep these failure domains distinct:

- Terraform apply failure: infrastructure was not safely reconciled.
- PostgreSQL/migration failure: do not boot the new Rails release.
- Kamal deploy failure: database changes may already be applied; fix or roll back the app image safely.
- `/up` or MCP metadata failure: public deployment is not healthy.
- Phase 0 acceptance/readiness failure: app deployment may be healthy, but staging has not passed its operational product gate.

Do not expose PostgreSQL publicly, inject owner credentials into long-running Rails containers, or weaken RLS/readiness checks to make staging appear green.
