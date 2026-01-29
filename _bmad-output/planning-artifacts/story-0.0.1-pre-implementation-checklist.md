# Story 0.0.1: Pre-Implementation Checklist

**Type**: Setup / Prerequisites  
**Priority**: P0 (Blocking)  
**Estimated Time**: 1-2 hours  
**Status**: Completed (2026-01-29)

---

## Overview

Before starting Sprint 1 (Phase 1: Foundation), you need to complete these manual setup tasks. This checklist ensures all external accounts, configurations, and decisions are in place.

---

## Checklist

### 1. Domain Name Configuration

**Why**: All services need a domain for HTTPS certificates and Cloudflare Tunnel routing.

- [ ] **1.1 Choose your domain structure**

  Options:
  ```
  Option A: Subdomain per service (recommended)
  ├── omni.yourdomain.com
  ├── argocd.yourdomain.com
  ├── nextcloud.yourdomain.com
  ├── vault.yourdomain.com (Vaultwarden)
  └── ...

  Option B: Path-based (single domain)
  ├── yourdomain.com/omni
  ├── yourdomain.com/argocd
  └── ... (more complex, not recommended)
  ```

- [ ] **1.2 Confirm your domain name**
  
  Write your domain here: `___________________`
  
  Examples: `homelab.example.com`, `home.smith.family`, `lab.pauldev.io`

- [ ] **1.3 Verify DNS is managed by Cloudflare**
  
  Go to: https://dash.cloudflare.com
  - Domain should show "Active" status
  - Nameservers should be Cloudflare's
  
  If not on Cloudflare yet:
  1. Add site in Cloudflare dashboard
  2. Update nameservers at your registrar
  3. Wait for propagation (up to 24h)

---

### 2. Cloudflare Account Setup

**Why**: Cloudflare Tunnel provides zero-trust access without opening ports.

- [ ] **2.1 Confirm Cloudflare account tier**
  
  Go to: https://dash.cloudflare.com → Your domain → Overview
  
  **Free tier is sufficient for MVP** ✅
  - Includes: Tunnel, basic WAF, DDoS protection
  - Limitations: 100k requests/day (plenty for homelab)
  
  Your tier: [ ] Free  [ ] Pro  [ ] Other: ________

- [ ] **2.2 Create API Token for external-dns & cert-manager**
  
  1. Go to: https://dash.cloudflare.com/profile/api-tokens
  2. Click "Create Token"
  3. Use template: "Edit zone DNS"
  4. Configure:
     - Zone Resources: Include → Specific zone → your domain
     - Permissions: Zone - DNS - Edit
  5. Click "Continue to summary" → "Create Token"
  6. **SAVE THE TOKEN SECURELY** (you'll need it later)
  
  Token saved: [ ] Yes (store in password manager)

- [ ] **2.3 Note your Cloudflare Zone ID**
  
  1. Go to: https://dash.cloudflare.com → Your domain → Overview
  2. Scroll down on right sidebar to "API" section
  3. Copy "Zone ID"
  
  Zone ID: `___________________`

---

### 3. Oracle Cloud Account Verification

**Why**: Oracle Cloud hosts the management VM (Omni, Keycloak) and CLOUD cluster.

- [ ] **3.1 Verify Always Free tier status**
  
  Go to: https://cloud.oracle.com → Governance → Limits, Quotas and Usage
  
  Check you have available:
  - [ ] VM.Standard.A1.Flex (ARM): 4 OCPUs, 24GB RAM total
  - [ ] Block Volume: 200GB
  - [ ] Object Storage: 20GB (we'll use OVH for backups instead)

- [ ] **3.2 Check ARM shape availability in your region**
  
  Go to: Compute → Instances → Create Instance
  - Select shape: VM.Standard.A1.Flex
  - Check if it's available or shows "Out of capacity"
  
  If out of capacity:
  - Try different availability domains
  - Try at off-peak hours (early morning)
  - Consider upgrading to paid tier temporarily
  
  ARM available: [ ] Yes  [ ] No (note region: ________)

- [ ] **3.3 Create or verify OCI API Key**
  
  For Terraform to provision resources:
  1. Go to: Profile → My Profile → API Keys
  2. Click "Add API Key"
  3. Download private key and save securely
  4. Note the fingerprint
  
  You'll need for `~/.oci/config`:
  ```
  [DEFAULT]
  user=ocid1.user.oc1..xxxxx
  fingerprint=xx:xx:xx:...
  tenancy=ocid1.tenancy.oc1..xxxxx
  region=eu-paris-1 (or your region)
  key_file=~/.oci/oci_api_key.pem
  ```
  
  OCI API configured: [ ] Yes

---

### 4. Secrets Management Setup

**Why**: External Secrets Operator needs a backend to fetch secrets from.

- [ ] **4.1 Choose secrets backend**
  
  Options:
  - [x] **Bitwarden Secrets Manager** (recommended for Phase 1)
    - If you have Bitwarden Premium/Teams/Enterprise
  - [ ] **1Password Connect** (alternative)
  - [ ] **HashiCorp Vault** (can add in Phase 2)
  - [ ] **Doppler** (SaaS alternative)
  - [ ] **SOPS + Age** (git-encrypted, simpler)
  
  Your choice: `___________________`

- [ ] **4.2 If Bitwarden: Create Machine Account**
  
  1. Go to: https://vault.bitwarden.com → Settings → Machine Accounts
  2. Create new machine account for "homelab-eso"
  3. Generate access token
  4. **SAVE THE TOKEN SECURELY**
  
  If you don't have Bitwarden Secrets Manager:
  - Consider SOPS + Age as a simpler alternative
  - We can configure this in Phase 2 instead
  
  Secrets backend ready: [ ] Yes  [ ] Will configure later

---

### 5. Proxmox Server Verification

**Why**: Proxmox is the foundation - everything runs on it.

- [ ] **5.1 Verify Proxmox is accessible**
  
  Open: https://192.168.68.51:8006
  - Can you log in? [ ] Yes
  - Note Proxmox version: `___________________` (should be 8.x)

- [ ] **5.2 Verify network configuration**
  
  In Proxmox UI → Node → System → Network:
  - [ ] `vmbr0` bridge exists
  - [ ] Bridge is connected to physical interface
  
  Note your network setup:
  - Bridge interface: `___________________`
  - IP range for VMs: `___________________` (e.g., 192.168.68.100-150)

- [ ] **5.3 Reserve IP addresses for clusters**
  
  In your router's DHCP settings, reserve these IPs (or note them for static assignment):
  
  | VM | Suggested IP | Your IP |
  |----|--------------|---------|
  | talos-dev | 192.168.68.100 | _______ |
  | talos-prod-cp | 192.168.68.101 | _______ |
  | talos-prod-worker | 192.168.68.102 | _______ |
  | gaming-vm (future) | 192.168.68.110 | _______ |
  
  IPs reserved: [ ] Yes  [ ] Will use DHCP

- [ ] **5.4 Verify storage**
  
  In Proxmox UI → Node → Disks:
  - [ ] System SSD visible (~1TB)
  - [ ] 2x HDD visible (~20TB each)
  
  Note: ZFS pool will be created in Story 1.1.2

- [ ] **5.5 Verify GPU for passthrough (optional for now)**
  
  In Proxmox shell:
  ```bash
  lspci | grep -i nvidia
  ```
  
  GPU detected: [ ] Yes → Model: `___________________`  [ ] No GPU

---

### 6. GitHub Repository Setup

**Why**: GitOps requires a Git repository for all configurations.

- [ ] **6.1 Initialize Git repository (if not done)**
  
  ```bash
  cd /Users/paul/Developer/Perso/homelab
  git init
  git add .
  git commit -m "Initial commit: BMad planning artifacts"
  ```

- [ ] **6.2 Create GitHub repository**
  
  1. Go to: https://github.com/new
  2. Name: `homelab` (or your preference)
  3. Visibility: Private (recommended) or Public
  4. Don't initialize with README (you have one)
  
  Repository URL: `___________________`

- [ ] **6.3 Push to GitHub**
  
  ```bash
  git remote add origin git@github.com:YOUR_USERNAME/homelab.git
  git branch -M main
  git push -u origin main
  ```

- [ ] **6.4 Create deploy key for ArgoCD (can do later)**
  
  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/argocd-deploy-key -N ""
  cat ~/.ssh/argocd-deploy-key.pub
  ```
  
  Add to GitHub: Settings → Deploy keys → Add deploy key
  - Title: "ArgoCD Homelab"
  - Key: (paste public key)
  - Allow write access: [ ] (not needed for GitOps)

---

### 7. Local Tools Installation

**Why**: You'll need these CLI tools on your Mac for management.

- [ ] **7.1 Install Homebrew packages**
  
  ```bash
  # Core tools
  brew install kubectl helm terraform ansible
  
  # Talos tools
  brew install siderolabs/tap/talosctl
  
  # ArgoCD CLI
  brew install argocd
  
  # Optional but useful
  brew install k9s kubectx jq yq
  ```

- [ ] **7.2 Verify installations**
  
  ```bash
  kubectl version --client
  terraform version
  talosctl version --client
  argocd version --client
  ```
  
  All tools installed: [ ] Yes

- [ ] **7.3 Install OCI CLI (for Oracle Cloud)**
  
  ```bash
  brew install oci-cli
  oci setup config  # Follow prompts
  ```

---

### 8. Final Decisions

- [ ] **8.1 Confirm architecture decisions**
  
  Review and confirm:
  - [ ] DEV cluster: Single node, 4GB RAM - OK for testing?
  - [ ] PROD cluster: 1 CP + 1 Worker, 16GB total - sufficient?
  - [ ] Oracle Cloud: Management VM + 2-node K8s cluster - OK?

- [ ] **8.2 Confirm service priorities**
  
  Phase 4 MVP services - confirm these are your priorities:
  - [ ] Nextcloud (file storage)
  - [ ] Vaultwarden (passwords)
  - [ ] Baïkal (calendar/contacts)
  - [ ] Comet (Stremio/Real-Debrid)
  - [ ] Navidrome (music)
  
  Any changes? `___________________`

---

## Summary

Once all checkboxes are complete, update the workflow status:

```yaml
# In bmm-workflow-status.yaml, update implementation-readiness:
- id: "implementation-readiness"
  status: "planning-artifacts/story-0.0.1-pre-implementation-checklist.md"
  completed: "2026-01-29T..."
  finalized: true
```

Then proceed to: `*sprint-planning`

---

## Quick Reference Card

| Item | Value |
|------|-------|
| Domain | `smadja.dev` |
| Cloudflare Zone ID | `bda8e2196f6b4f1684c6c9c06d996109` |
| Cloudflare API Token | (in password manager) |
| OCI Region | `eu-paris-1` (France Central) |
| Proxmox IP | `192.168.68.51` |
| GitHub Repo | `https://github.com/SmadjaPaul/homelab` |
| Secrets Backend | TBD (Bitwarden or SOPS)

---

*Story 0.0.1 Complete when all checkboxes are checked*
