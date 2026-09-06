# LMX Terraform

Terraform owns the provider-level infrastructure that must exist before Kamal can deploy LMX. Kamal remains responsible for Docker, kamal-proxy, Rails deployment, application secrets, and rollback.

Kubernetes is intentionally not part of the staging architecture.

## Layout

```text
infra/terraform/
  bin/
    write-backend-config
  environments/
    staging/
      backend.s3.hcl.example
      cloud-init.yaml.tftpl
      main.tf
      outputs.tf
      providers.tf
      terraform.tfvars.example
      variables.tf
      versions.tf
```

See [`GITHUB_ACTIONS.md`](GITHUB_ACTIONS.md) for the exact repository variables, read-only plan credentials, protected staging apply credentials, and remote-state setup contract.

## Staging resources

The first environment creates:

- one Hetzner Cloud server
- one SSH deploy key registered in the Hetzner project
- one Hetzner Cloud Firewall
- one persistent Hetzner Cloud Volume attached and automatically mounted as ext4

The server is disposable. The data volume is protected by default and is the durable boundary intended for PostgreSQL data once the Kamal database accessory is wired.

## Versions

The configuration currently targets Terraform 1.16.x and `hetznercloud/hcloud` 1.68.0. Keep provider upgrades explicit and review their plans before applying them.

## Secrets and inputs

Do not commit real values in `*.tfvars`, backend configuration, Terraform state, or plan files.

The Hetzner provider reads its API token from:

```bash
export HCLOUD_TOKEN=...
```

Pass environment-specific values either through an untracked tfvars file or Terraform environment variables:

```bash
export TF_VAR_staging_hostname=staging.example.com
export TF_VAR_ssh_public_key="$(cat ~/.ssh/lmx_staging.pub)"
export TF_VAR_ssh_source_ips='["0.0.0.0/0","::/0"]'
```

Opening SSH globally is acceptable only with key-only authentication and is mainly useful for GitHub-hosted deployment runners. Prefer narrower CIDRs or a private runner when available.

## Remote state

The environment declares an S3 backend but intentionally keeps its concrete bucket, endpoint, and credentials outside Terraform source.

Remote state is mandatory before shared staging applies. The state bucket must exist outside this Terraform configuration so destroying or replacing staging cannot destroy the state store itself.

For local operation, copy `backend.s3.hcl.example` to `backend.hcl` and initialize with:

```bash
terraform -chdir=environments/staging init -backend-config=backend.hcl
```

For GitHub Actions, `bin/write-backend-config` generates the non-secret backend configuration from repository variables while credentials stay in environment variables.

S3 lock files are enabled with `use_lockfile = true`. When using AWS S3, enable bucket versioning for state recovery. S3-compatible storage is supported through an explicit endpoint/compatibility mode and must be tested for locking before long-lived staging data depends on it.

Never run shared staging applies from local state.

## Local validation

```bash
terraform fmt -check -recursive .
bash -n bin/write-backend-config
terraform -chdir=environments/staging init -backend=false
terraform -chdir=environments/staging validate
```

GitHub Actions runs the same checks automatically for changes under `infra/terraform/**`.

## Automated plan/apply boundary

The GitHub Terraform workflow separates credentials intentionally:

```text
PR
  -> fmt / validate
  -> read-only Hetzner token
  -> read-only remote state
  -> terraform plan -lock=false

manual apply from main
  -> protected GitHub Environment: staging
  -> write Hetzner token
  -> write/locking remote-state credentials
  -> terraform plan -out=tfplan
  -> terraform apply tfplan
```

If the read-only plan credentials have not been configured, pull requests still validate successfully and report that the cloud plan was skipped.

`apply` can only be requested through `workflow_dispatch` from `main`, requires the literal confirmation `apply-staging`, and is additionally gated by the GitHub `staging` environment. Configure a required reviewer on that environment before adding write credentials.

## First local plan/apply

After remote state and secrets exist:

```bash
terraform -chdir=environments/staging init -backend-config=backend.hcl
terraform -chdir=environments/staging plan -var-file=terraform.tfvars
terraform -chdir=environments/staging apply -var-file=terraform.tfvars
```

After apply, Terraform becomes the source of truth for the Kamal host:

```bash
export LMX_STAGING_HOST="$(terraform -chdir=environments/staging output -raw staging_ipv4)"
export LMX_STAGING_HOSTNAME="$(terraform -chdir=environments/staging output -raw staging_hostname)"
```

## Next infrastructure slice

After remote state is configured and the first reviewed apply succeeds:

1. verify the volume mount and state recovery/locking behavior
2. add the PostgreSQL Kamal accessory backed by `data_volume_mount_path`
3. automate the four Rails databases plus owner/runtime roles
4. manage staging DNS with the actual DNS provider
5. feed Terraform outputs directly into the Kamal staging deployment workflow
6. add post-deploy `/up`, Phase 0, and MCP acceptance gates
7. after the lifecycle is proven, decide whether protected applies should remain manual or trigger automatically from `main`
