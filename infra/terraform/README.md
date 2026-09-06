# LMX Terraform

Terraform owns the provider-level infrastructure that must exist before Kamal can deploy LMX. Kamal remains responsible for Docker, kamal-proxy, Rails deployment, application secrets, and rollback.

Kubernetes is intentionally not part of the staging architecture.

## Layout

```text
infra/terraform/
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

Do not commit real values in `*.tfvars` or `backend.hcl`.

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

The environment declares an S3 backend but intentionally does not commit backend credentials or provider-specific endpoint values. Copy `backend.s3.hcl.example` to `backend.hcl`, fill it with the chosen S3-compatible state store, and initialize with:

```bash
terraform -chdir=environments/staging init -backend-config=backend.hcl
```

Never run shared staging applies from local state.

## Local validation

```bash
terraform fmt -check -recursive .
terraform -chdir=environments/staging init -backend=false
terraform -chdir=environments/staging validate
```

GitHub Actions runs the same checks automatically for changes under `infra/terraform/**`.

## First plan/apply

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

After the first host is provisioned and the volume mount is verified:

1. add the PostgreSQL Kamal accessory backed by `data_volume_mount_path`
2. automate the four Rails databases plus owner/runtime roles
3. manage staging DNS with the actual DNS provider
4. add GitHub Environment `staging` secrets and a reviewed Terraform plan/apply workflow
5. feed Terraform outputs directly into the Kamal staging deployment workflow
6. run Phase 0 and MCP acceptance after deployment
