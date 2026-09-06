# Terraform and staging GitHub Actions

LMX staging uses two separate GitHub Environment boundaries:

1. `staging-infra` owns cloud writes and Terraform state writes.
2. `staging` owns application deployment secrets, SSH access, and read-only Terraform state access.

This separation lets application deploys become hands-free without giving the deploy workflow permission to create, replace, or delete Hetzner resources.

## Repository variables

Configure these under repository Actions variables:

| Variable | Required | Example | Purpose |
| --- | --- | --- | --- |
| `TF_STATE_BUCKET` | yes | `lmx-terraform-state` | Remote state bucket |
| `TF_STATE_REGION` | yes | `auto` or provider region | S3 backend region |
| `TF_STATE_KEY` | no | `lmx/staging/terraform.tfstate` | State object key |
| `TF_STATE_ENDPOINT` | only for S3-compatible storage | `https://...` | Custom S3 API endpoint |
| `TF_STATE_S3_COMPATIBLE` | no | `true` | Enables S3-compatible backend flags |
| `LMX_STAGING_HOSTNAME` | yes | `staging.example.com` | Public Kamal/TLS hostname |
| `LMX_STAGING_SSH_PUBLIC_KEY` | yes | `ssh-ed25519 ...` | Public deploy key registered with Hetzner |
| `LMX_STAGING_SSH_SOURCE_IPS` | yes | `["0.0.0.0/0","::/0"]` | JSON Terraform list of allowed SSH CIDRs |
| `LMX_STAGING_AUTO_DEPLOY` | no | `false` | Set to `true` only after the first manual staging deploy succeeds |

The SSH public key is not secret. Its private key must never be stored in Terraform variables or state.

## Repository secrets for pull-request plans

Same-repository Terraform pull requests may use read-only credentials:

- `HCLOUD_TOKEN_PLAN` - Hetzner Cloud API token with Read permission
- `TF_STATE_ACCESS_KEY_ID_PLAN` - state-store list/read credential
- `TF_STATE_SECRET_ACCESS_KEY_PLAN` - matching read-only secret

Plans run with `-lock=false`, so these credentials do not need state or lock-file write permission. Fork pull requests never receive them.

If plan credentials are absent, `fmt`, `init -backend=false`, and `validate` still run; the remote cloud plan is reported as skipped.

## `staging-infra` environment

Create a GitHub Environment named exactly:

```text
staging-infra
```

This is the infrastructure write boundary. Configure a required reviewer and disable administrator bypass if you want strict approval.

Environment secrets:

- `HCLOUD_TOKEN` - Hetzner Cloud Read & Write token
- `TF_STATE_ACCESS_KEY_ID` - state-store read/write credential
- `TF_STATE_SECRET_ACCESS_KEY` - matching state-store secret

The state credential needs state object read/write access plus get/put/delete access to `<state-key>.tflock` because native S3 lock files are enabled.

Run an apply with Actions -> Terraform -> Run workflow, choose `apply`, and enter `apply-staging`. Normal pushes and pull requests never apply infrastructure.

## `staging` environment

Create a second GitHub Environment named exactly:

```text
staging
```

This is the application deployment boundary. For hands-free staging, do not require a reviewer here; keep the workflow itself restricted to successful `CI` push runs on `main`. The workflow has no Hetzner API token and cannot apply Terraform.

Environment secrets for infrastructure discovery and SSH:

- `TF_STATE_ACCESS_KEY_ID` - read-only state credential
- `TF_STATE_SECRET_ACCESS_KEY` - matching read-only state secret
- `LMX_STAGING_SSH_PRIVATE_KEY` - private half of `LMX_STAGING_SSH_PUBLIC_KEY`

Environment application secrets:

- `RAILS_MASTER_KEY`
- `POSTGRES_OWNER_PASSWORD`
- `POSTGRES_RUNTIME_PASSWORD`
- `LMX_PHASE0_WORKSPACE_ID`
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`
- `OTEL_EXPORTER_OTLP_ENDPOINT`
- `OTEL_EXPORTER_OTLP_HEADERS` when required by the collector
- `LMX_MCP_OAUTH_AUTHORIZATION_SERVERS`
- `LMX_MCP_OAUTH_SCOPES`
- `LMX_MCP_OAUTH_INTROSPECTION_ENDPOINT`
- `LMX_MCP_OAUTH_INTROSPECTION_CLIENT_ID`
- `LMX_MCP_OAUTH_INTROSPECTION_CLIENT_SECRET`

No database URLs or GHCR password are stored as staging secrets. The workflow derives all eight database URLs from the two PostgreSQL passwords and uses the workflow-scoped GitHub token for GHCR.

## Automated deployment flow

`.github/workflows/deploy-staging.yml` can be launched manually from `main`. Once the first deployment succeeds, set:

```text
LMX_STAGING_AUTO_DEPLOY=true
```

A successful `CI` workflow caused by a `push` to `main` then triggers:

```text
read Terraform outputs
-> configure SSH
-> derive runtime/migration DB URLs
-> bootstrap Docker if needed
-> verify persistent Hetzner volume
-> create Kamal network if needed
-> boot/start PostgreSQL accessory
-> wait for PostgreSQL
-> run owner migrations over an SSH tunnel
-> provision/update restricted lmx_app grants
-> kamal deploy
-> GET /up
-> verify MCP protected-resource metadata
-> run Phase 0 source acceptance
-> run Phase 0 readiness
```

Runtime Rails URLs point to `lmx-staging-db:5432` on the private Kamal Docker network. Migration URLs point to `127.0.0.1:15432` on the GitHub runner and exist only while the SSH tunnel is active. PostgreSQL itself remains published only on the staging host loopback.

## Remote state requirements

The state bucket exists outside the LMX staging Terraform configuration so the infrastructure does not own its own state store.

For AWS S3, enable bucket versioning. For S3-compatible storage, set `TF_STATE_S3_COMPATIBLE=true` and `TF_STATE_ENDPOINT` and prove locking/recovery before relying on it long term.

Before putting durable PostgreSQL data on the volume:

1. run one successful reviewed Terraform apply
2. confirm the remote state object exists
3. confirm a read-only plan can read it
4. confirm a competing writer is blocked by the lock file
5. confirm state object version recovery works
6. run the first manual Deploy staging workflow
7. only then enable `LMX_STAGING_AUTO_DEPLOY=true`
