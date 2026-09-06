# Terraform GitHub Actions

The Terraform workflow has three safety levels:

1. validation never requires cloud credentials
2. pull-request plans use read-only Hetzner and state credentials
3. staging applies use separate write credentials behind the GitHub `staging` environment

`terraform apply` is never triggered by a pull request or by a normal push.

## Repository variables

Configure these under repository Actions variables. They are non-secret deployment inputs shared by plan and apply jobs.

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

The SSH public key is not secret. The private key must never be stored in Terraform variables or state.

## Repository secrets for plans

Pull-request plans must not have write access to Hetzner or to Terraform state.

Configure:

- `HCLOUD_TOKEN_PLAN` - Hetzner Cloud API token with Read permission
- `TF_STATE_ACCESS_KEY_ID_PLAN` - state-store credential with list/read permission
- `TF_STATE_SECRET_ACCESS_KEY_PLAN` - matching read-only secret

The plan runs with `-lock=false`, so the state-store plan credential does not need lock-file write/delete permission.

Fork pull requests never receive the plan credentials. A same-repository pull request is required for the cloud plan job.

If these credentials or required variables have not been configured yet, validation remains green and the cloud plan reports that it was skipped.

## GitHub environment for applies

Create a GitHub Environment named exactly:

```text
staging
```

Configure a required reviewer before adding write credentials. Disable administrator bypass if you want the approval boundary to be strict.

Environment secrets:

- `HCLOUD_TOKEN` - Hetzner Cloud API token with Read & Write permission
- `TF_STATE_ACCESS_KEY_ID` - state-store read/write credential
- `TF_STATE_SECRET_ACCESS_KEY` - matching state-store secret

The write state credential needs access to the state object and, because S3 lock files are enabled, get/put/delete access to `<state-key>.tflock`.

Do not reuse the plan token as the apply token.

## Remote state requirements

The state bucket exists outside the LMX staging Terraform configuration. This avoids making the infrastructure state store dependent on the infrastructure it manages.

For AWS S3, enable bucket versioning and use native S3 locking via `use_lockfile = true`.

For S3-compatible storage, set `TF_STATE_S3_COMPATIBLE=true` and `TF_STATE_ENDPOINT`. The helper emits the compatibility flags used by the S3 backend. S3-compatible support is provider-dependent, so prove locking and recovery before relying on it for production.

Credentials are supplied through `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` only. They are never written into the generated backend HCL.

## Pull-request plan

After the variables and read-only secrets exist, every same-repository pull request touching Terraform automatically runs:

```text
fmt -> validate -> remote-state init -> terraform plan -lock=false
```

The plan is printed into the workflow job summary.

## Staging apply

Apply is intentionally explicit for the bootstrap phase:

1. open Actions -> Terraform -> Run workflow
2. select `action = apply`
3. enter `confirmation = apply-staging`
4. approve the `staging` environment deployment when GitHub asks

The job then executes:

```text
remote-state init
-> terraform plan -out=tfplan
-> terraform apply tfplan
-> publish staging IP/hostname/volume outputs
```

This keeps the first infrastructure creation reviewed. Once the staging lifecycle has been proven, the trigger can be changed to `push` on `main` while retaining the protected `staging` environment approval gate.

## State recovery test

Before the first long-lived staging workload:

1. run one successful apply
2. confirm the remote state object exists
3. confirm a plan can read it with the read-only credentials
4. confirm locking prevents a competing writer
5. confirm the bucket/versioning policy allows recovery of a previous state object version

Do not deploy PostgreSQL data until remote state and volume delete protection have both been proven.
