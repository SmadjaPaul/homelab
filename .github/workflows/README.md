# GitHub Actions – CI/CD Workflows

## Overview

This directory contains GitHub Actions workflows for the homelab infrastructure automation.

## Available Workflows

### Infrastructure Deployment

- **Terraform Oracle Cloud** (`terraform-oci.yml`)
  - Deploys Oracle Cloud infrastructure (VMs, networking, Vault)
  - Trigger: PR/push to `terraform/oracle-cloud/**` or manual dispatch
  - Supports: plan, apply, destroy, force-unlock

- **Terraform Cloudflare** (`terraform-cloudflare.yml`)
  - Manages DNS, tunnels, and Zero Trust policies
  - Trigger: PR/push to `terraform/cloudflare/**` or manual dispatch
  - Uses Doppler for secrets (not OCI Vault)

- **Terraform Authentik** (`terraform-authentik.yml`)
  - Configures Authentik applications and policies
  - Trigger: Manual dispatch
  - Requires: `AUTHENTIK_URL` and `AUTHENTIK_TOKEN` secrets

### Docker Deployment

- **Docker CD** (`CD.yml`)
  - Deploys Docker containers to target hosts
  - Trigger: Push to `docker/**` or manual dispatch
  - Uses Doppler for secrets management
  - Supports deploying to specific hosts and folders

### CI and Validation

- **CI** (`ci.yml`)
  - Validates secrets format (SSH keys)
  - Validates Kubernetes manifests
  - Runs on PRs and pushes (excludes Terraform paths)

- **Validate Secrets** (`validate-secrets.yml`)
  - Reusable workflow for secret validation
  - Checks SSH key format and required secrets

- **Flux Diff** (`flux-diff.yml`)
  - Shows diffs for Kubernetes manifests on PRs
  - Uses Flux CLI for GitOps diffing

### Security

- **Security** (`security.yml`)
  - Runs security scans (Gitleaks, Trivy, tfsec, Kubescape)
  - Trigger: Manual dispatch
  - Note: SARIF upload requires GitHub Advanced Security

### Maintenance

- **Terraform Drift Detection** (`terraform-drift-detection.yml`)
  - Detects infrastructure drift for OCI and Cloudflare
  - Runs on schedule (weekly)

- **OCI SSH Key Rotation** (`oci-ssh-key-rotate.yml`)
  - Rotates SSH keys for OCI management VM
  - Updates GitHub secrets automatically (requires GH_TOKEN)

- **Labels** (`labels.yml`)
  - Manages repository labels

## Required Secrets

### Cloudflare
- `CLOUDFLARE_API_TOKEN` - API token for DNS/tunnel management
- `CLOUDFLARE_ACCOUNT_ID` - Cloudflare account ID
- `CLOUDFLARE_TUNNEL_SECRET` - Tunnel secret
- `CLOUDFLARE_ZONE_ID` - Zone ID for smadja.dev

### Oracle Cloud (OCI)
- `OCI_CLI_USER` - OCI user OCID
- `OCI_CLI_TENANCY` - OCI tenancy OCID
- `OCI_CLI_FINGERPRINT` - API key fingerprint
- `OCI_CLI_REGION` - OCI region
- `OCI_CLI_KEY_CONTENT` - API key content
- `OCI_OBJECT_STORAGE_NAMESPACE` - Object storage namespace for Terraform backend
- `OCI_COMPARTMENT_ID` - Compartment ID for resources

### Authentik
- `AUTHENTIK_URL` - Authentik instance URL (e.g., https://auth.smadja.dev)
- `AUTHENTIK_TOKEN` - API token for Terraform

### SSH Keys
- `SSH_PUBLIC_KEY` - Public SSH key for VM access
- `SSH_PRIVATE_KEY` - Private key for OCI management VM

### GitHub (optional)
- `GH_TOKEN` - GitHub PAT for updating secrets automatically

## Usage

### Deploy Infrastructure

1. **Oracle Cloud**: Trigger `Terraform Oracle Cloud` workflow manually or push to `terraform/oracle-cloud/`
2. **Cloudflare**: Trigger `Cloudflare Infrastructure` workflow manually or push to `terraform/cloudflare/`
3. **Authentik**: Trigger `Terraform Authentik` workflow manually after OCI deployment

### Deploy Docker Services

Push changes to `docker/` directory or trigger `Docker CD` workflow manually with target host and folder.

### Folder to Host Mapping (CD.yml)

| Folder | Host |
|--------|------|
| alloy | all |
| arm | ARM |
| caddy | proxy |
| databases | docker |
| downloaders | downloaders |
| geohub | Ubu |
| omni | omni |
| ollama | ollama |
| blocky | blocky-HA |
| exporters | Ubu |
| jellyfin | Ark-Ripper |
| npm | Nginx-Proxy-Manager |
| wazuh | wazuh |

## Notes

- All workflows use Doppler for secrets management (not OCI Vault or Bitwarden)
- Terraform backend is stored in OCI Object Storage
- Docker deployments require a self-hosted runner with SSH access to target hosts
