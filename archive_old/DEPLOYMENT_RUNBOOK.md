# Homelab Deployment Runbook

This guide walks you through deploying your entire homelab infrastructure from scratch using the new Doppler-based setup.

## Prerequisites

- [ ] Doppler CLI installed and logged in
- [ ] GitHub repository with secrets configured
- [ ] Oracle Cloud account with API keys
- [ ] Cloudflare account with API token
- [ ] Proxmox cluster access
- [ ] SSH keys generated for VM access

---

## Phase 1: Doppler Setup

### Step 1.1: Create Doppler Projects

```bash
# Create all required projects
doppler projects create infrastructure
doppler projects create databases
doppler projects create apps
doppler projects create monitoring
doppler projects create servarr
doppler projects create authentik
doppler projects create litellm
```

### Step 1.2: Add Infrastructure Secrets

**Cloudflare token (you have this):**
```bash
doppler secrets set CLOUDFLARE_API_TOKEN="ywErWkXSisoP0I1g_nCPesDhOrRqWq5PKS4Kuamw" -p infrastructure
```

**OCI credentials:**
```bash
doppler secrets set OCI_CLI_USER="your-oci-user-ocid" -p infrastructure
doppler secrets set OCI_CLI_TENANCY="your-tenancy-ocid" -p infrastructure
doppler secrets set OCI_CLI_FINGERPRINT="your-fingerprint" -p infrastructure
doppler secrets set OCI_CLI_REGION="eu-paris-1" -p infrastructure
doppler secrets set OCI_CLI_KEY_CONTENT="$(cat ~/.oci/oci_api_key.pem)" -p infrastructure
doppler secrets set OCI_OBJECT_STORAGE_NAMESPACE="your-namespace" -p infrastructure
doppler secrets set OCI_COMPARTMENT_ID="your-compartment-id" -p infrastructure
```

**Proxmox credentials:**
```bash
doppler secrets set PROXMOX_API_TOKEN="your-token" -p infrastructure
doppler secrets set PROXMOX_API_SECRET="your-secret" -p infrastructure
```

**SSH keys:**
```bash
doppler secrets set SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)" -p infrastructure
```

### Step 1.3: Create Service Tokens for CI/CD

```bash
# For Docker deployments (CD.yml workflow)
doppler configs tokens create --config prd docker-deploy-token -p infrastructure --plain

# For Terraform modules (save these for GitHub secrets)
doppler configs tokens create --config prd servarr-terraform -p servarr --plain
doppler configs tokens create --config prd authentik-terraform -p authentik --plain
doppler configs tokens create --config prd litellm-terraform -p litellm --plain
```

**Add to GitHub Repository Secrets:**
- `DOPPLER_TOKEN` - infrastructure project token
- `DOPPLER_TOKEN_SERVARR` - servarr project token
- `DOPPLER_TOKEN_AUTHENTIK` - authentik project token
- `DOPPLER_TOKEN_LITELLM` - litellm project token

---

## Phase 2: Infrastructure Deployment (Terraform)

### Step 2.1: Deploy Oracle Cloud Infrastructure

```bash
cd terraform/oracle-cloud

# Initialize
terraform init

# Plan
terraform plan

# Apply (only creates VMs and networking, no Vault)
terraform apply
```

**What gets created:**
- Management VM (Ubuntu)
- 2x Kubernetes nodes (Talos)
- Virtual Cloud Network (VCN)
- Security lists and subnets

### Step 2.2: Deploy Cloudflare

```bash
cd terraform/cloudflare

# Initialize
terraform init

# Create terraform.tfvars
cat > terraform.tfvars << EOF
cloudflare_api_token = "ywErWkXSisoP0I1g_nCPesDhOrRqWq5PKS4Kuamw"
zone_id = "your-zone-id"
domain = "smadja.dev"
enable_tunnel = false  # Enable later after tunnel is configured
EOF

# Plan and apply
terraform plan
terraform apply
```

### Step 2.3: Deploy Proxmox VMs (Optional)

```bash
cd terraform/proxmox

# Set credentials via env or variables
terraform init
terraform plan
terraform apply
```

---

## Phase 3: Kubernetes Cluster Setup

### Step 3.1: Bootstrap Talos Cluster

```bash
cd kubernetes/talos

# Follow Talos documentation to:
# 1. Generate machine configs
# 2. Apply to OCI nodes
# 3. Bootstrap etcd
# 4. Get kubeconfig

# Example workflow:
talhelper genconfig
talosctl apply-config -n <node-ip> --file controlplane.yaml
talosctl bootstrap -n <node-ip>
talosctl kubeconfig -n <node-ip>
```

### Step 3.2: Install Flux CD

```bash
# Install Flux CLI
brew install fluxcd/tap/flux

# Bootstrap Flux
flux bootstrap github \
  --owner=smadja-paul \
  --repository=homelab \
  --branch=main \
  --path=kubernetes/clusters/production \
  --personal
```

### Step 3.3: Configure External Secrets Operator

```bash
# Create Doppler token secret in cluster
kubectl create namespace external-secrets
kubectl create secret generic doppler-token-auth \
  --from-literal=dopplerToken='dp.st.your-token' \
  -n external-secrets

# Flux will automatically apply external-secrets configuration
# Wait for it to sync:
flux reconcile source git flux-system
flux reconcile kustomization external-secrets
```

---

## Phase 4: Core Services Deployment

### Step 4.1: Deploy Databases

```bash
cd docker/databases

# Add database secrets to Doppler first:
doppler secrets set POSTGRES_PASSWORD="secure-password" -p databases
doppler secrets set MYSQL_ROOT_PASSWORD="secure-password" -p databases

# Deploy using Doppler wrapper
cd ../..
./docker/doppler-compose.sh databases up -d
```

### Step 4.2: Deploy Infrastructure Services

```bash
# Blocky DNS
./docker/doppler-compose.sh blocky up -d

# Nginx Proxy Manager
./docker/doppler-compose.sh npm up -d

# Caddy proxy (if using instead of NPM)
./docker/doppler-compose.sh proxy up -d
```

### Step 4.3: Deploy Applications

```bash
# ARM server (Gitea, Gotify, Homepage)
./docker/doppler-compose.sh arm up -d

# Media server (Jellyfin) - requires GPU setup first
# ./docker/doppler-compose.sh jellyfin up -d

# Media stack (Sonarr, Radarr, etc.)
./docker/doppler-compose.sh ubu up -d

# Ollama AI
./docker/doppler-compose.sh ollama up -d
```

---

## Phase 5: Terraform-Managed Services

### Step 5.1: Deploy Authentik (after it's running in Docker/K8s)

1. First, deploy Authentik via Docker or Kubernetes
2. Get the API token from Authentik UI
3. Add to Doppler:

```bash
doppler secrets set AUTHENTIK_URL="https://auth.smadja.dev" -p authentik
doppler secrets set AUTHENTIK_TOKEN="your-token" -p authentik
```

4. Run Terraform:

```bash
cd terraform/authentik
export DOPPLER_TOKEN=$(doppler configs tokens create --config prd temp -p authentik --plain)
terraform init
terraform plan
terraform apply
```

### Step 5.2: Deploy Servarr Stack (Optional)

**Prerequisites:** Servarr apps must be running and API keys generated

```bash
# 1. Deploy servarr apps first via Docker/K8s
# 2. Get API keys from each app
# 3. Add to Doppler:

doppler secrets set SONARR_API_KEY="key" -p servarr
doppler secrets set RADARR_API_KEY="key" -p servarr
doppler secrets set PROWLARR_API_KEY="key" -p servarr
# ... etc

# 4. Run Terraform
cd terraform/servarr
export DOPPLER_TOKEN=$(doppler configs tokens create --config prd temp -p servarr --plain)
terraform init
terraform plan
terraform apply
```

### Step 5.3: Deploy LiteLLM (Optional)

```bash
doppler secrets set LITELLM_URL="https://llm.smadja.dev" -p litellm
doppler secrets set LITELLM_MASTER_KEY="master-key" -p litellm

cd terraform/litellm
export DOPPLER_TOKEN=$(doppler configs tokens create --config prd temp -p litellm --plain)
terraform init
terraform plan
terraform apply
```

---

## Phase 6: Monitoring & Maintenance

### Step 6.1: Deploy Monitoring Stack

```bash
# Add monitoring secrets
doppler secrets set SMTP_PASSWORD="password" -p monitoring

# Deploy via Kubernetes (Flux will handle this)
# Or manually:
# cd docker/monitoring
# docker compose up -d
```

### Step 6.2: Configure Wazuh (Optional)

```bash
./docker/doppler-compose.sh wazuh up -d
```

---

## GitHub Actions Automation

### Workflows Available:

1. **CD.yml** - Deploys Docker services on push to main
2. **Terraform OCI** - Manages Oracle Cloud infrastructure
3. **Terraform Cloudflare** - Manages DNS and tunnels
4. **Terraform Authentik** - Manages Authentik configuration
5. **Security** - Runs security scans (manual trigger)
6. **Flux Diff** - Shows K8s manifest diffs on PRs

### Required GitHub Secrets:

```yaml
# Cloudflare
CLOUDFLARE_API_TOKEN
CLOUDFLARE_ACCOUNT_ID
CLOUDFLARE_TUNNEL_SECRET
CLOUDFLARE_ZONE_ID

# OCI
OCI_CLI_USER
OCI_CLI_TENANCY
OCI_CLI_FINGERPRINT
OCI_CLI_REGION
OCI_CLI_KEY_CONTENT
OCI_OBJECT_STORAGE_NAMESPACE
OCI_COMPARTMENT_ID

# SSH
SSH_PUBLIC_KEY
OCI_MGMT_SSH_PRIVATE_KEY

# Doppler
DOPPLER_TOKEN
DOPPLER_TOKEN_SERVARR
DOPPLER_TOKEN_AUTHENTIK
DOPPLER_TOKEN_LITELLM

# Authentik
AUTHENTIK_URL
AUTHENTIK_TOKEN
```

---

## Troubleshooting

### Common Issues:

**Doppler CLI not found:**
```bash
brew install doppler  # macOS
# or
curl -Ls https://cli.doppler.com/install.sh | sudo sh  # Linux
```

**Terraform state lock:**
```bash
cd terraform/<module>
terraform force-unlock <lock-id>
```

**Flux not syncing:**
```bash
flux reconcile source git flux-system
flux reconcile kustomization <name>
```

**External Secrets not fetching:**
```bash
kubectl get externalsecrets -A
kubectl describe externalsecret <name> -n <namespace>
```

---

## Next Steps

1. ✅ Review this runbook
2. ✅ Set up Doppler projects and add your secrets
3. ✅ Deploy Oracle Cloud infrastructure
4. ✅ Bootstrap Kubernetes cluster
5. ✅ Deploy core services
6. ✅ Configure remaining Terraform modules as needed

**Need help?** Check the logs in GitHub Actions or run commands locally with verbose output.

---

*Last updated: 2024-02-12*
*Infrastructure version: 2.0 (Doppler-based)*
