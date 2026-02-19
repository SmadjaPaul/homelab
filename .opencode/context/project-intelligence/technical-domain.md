<!-- Context: project-intelligence/technical | Priority: high | Version: 4.0 | Updated: 2026-02-19 -->

# Technical Domain

> Document the technical foundation, architecture, and key decisions for the homelab.

## Quick Reference

- **Purpose**: Understand how the homelab works technically
- **Update When**: New infrastructure, services, or tech stack changes
- **Audience**: Homelab owner, automation

## Primary Stack

| Layer | Technology | Version | Rationale |
|-------|-----------|---------|-----------|
| Cloud | OCI (Oracle Cloud) | N/A | Free tier, good for homelabs |
| IaC | Terraform | 1.x | Cloud infrastructure (OCI, Cloudflare, Authentik) |
| Orchestration | Kubernetes (OKE) | 1.29+ | Container orchestration |
| GitOps | Flux | Latest | Declarative CD for Kubernetes |
| Secrets | Doppler | N/A | Secret storage, synced via External Secrets |
| Networking | Cloudflare | Free tier | DNS, Tunnel, Access |
| Auth | Authentik | Latest | IDP for SSO |
| CI/CD | GitHub Actions | N/A | Automation pipelines |

## Architecture Pattern

```
Type: Multi-cluster Kubernetes with GitOps
Pattern: Git → Flux → Kubernetes + External Secrets (Doppler)
Clusters: OCI OKE (production)
```

### Networking Flow

```
Internet → Cloudflare → Cloudflare Tunnel → Kubernetes Services
                    ↓
              Cloudflare Access (Authentik OAuth)
                    ↓
              Authentik (IDP)
```

### Why This Architecture?

- OKE provides managed Kubernetes with free tier
- Flux manages ALL Kubernetes resources via GitOps
- Doppler stores secrets, External Secrets Operator syncs to cluster
- Terraform only for cloud infra (OCI, Cloudflare, Authentik setup)
- Cloudflare Tunnel exposes services securely
- Authentik + Cloudflare Access provides RBAC

## Project Structure

```
homelab/
├── kubernetes/              # Kubernetes configurations (Flux-managed)
│   ├── apps/               # Application manifests by category
│   │   ├── automation/     # n8n, automation tools
│   │   ├── infra/          # traefik, authentik, aiven-operator
│   │   └── public/         # Public-facing apps
│   ├── bootstrap/          # Cluster bootstrap (Flux, RBAC)
│   └── clusters/          # OCI cluster configs
├── .github/workflows/      # GitHub Actions CI/CD
├── scripts/                # Utility scripts
├── docs/                   # Documentation
└── terraform/             # Terraform IaC (OCI, Cloudflare, Authentik)
```

## Key Technical Decisions

| Decision | Rationale | Impact |
|----------|-----------|--------|
| OCI/OKE | Free tier, good documentation | Budget-friendly |
| Flux for K8s | GitOps for all K8s resources | Everything in git |
| Terraform for infra | Only cloud resources | OCI, Cloudflare, Authentik |
| Doppler for secrets | Centralized secret storage | Synced via External Secrets |
| Cloudflare Access | Zero-trust, free tier | Secure access with RBAC |
| Authentik | Open source IDP | SSO for all services |

## Integration Points

| System | Purpose | Protocol | Direction |
|--------|---------|----------|-----------|
| OKE | Kubernetes cluster | Kubernetes API | Internal |
| OCI API | Cloud resources | REST | Outbound |
| Flux | GitOps sync (ALL K8s) | Kubernetes API | Internal |
| Doppler | Secret storage | HTTPS | Outbound |
| External Secrets Operator | Sync secrets | Kubernetes API | Internal |
| GitHub Actions | CI/CD | HTTPS | Outbound |
| Cloudflare | DNS, Tunnel, Access | HTTPS | Outbound |
| Authentik | Identity Provider | OAuth/OIDC | Internal |

## Secrets Management

### Flow
1. Secrets stored in Doppler
2. Flux manages ExternalSecret resources in Kubernetes
3. External Secrets Operator syncs secrets from Doppler to cluster

### Terraform vs Flux
- **Terraform**: Cloud infrastructure only (OCI, Cloudflare, Authentik deployment)
- **Flux**: All Kubernetes resources (including ExternalSecret, ClusterSecretStore)

## Development Workflow

```
Setup: task -l (see available commands)
Add App: Create HelmRelease in kubernetes/apps/{category}/{app}/
Update Secrets: Update in Doppler, Flux syncs automatically
Validate: kubectl, flux get
```

## Deployment

```
Platform: Oracle Kubernetes Engine (OKE)
GitOps: Flux with Kustomize
Secrets: Doppler + External Secrets Operator (Flux-managed)
CI/CD: GitHub Actions
Infra: Terraform (OCI, Cloudflare, Authentik)
Networking: Cloudflare Tunnel + Access
Auth: Authentik (IDP)
```

## Onboarding Checklist

- [ ] Know the primary tech stack (Terraform, Flux, Doppler, GitHub Actions)
- [ ] Understand Flux manages ALL Kubernetes resources
- [ ] Know Terraform only for cloud infra (OCI, Cloudflare, Authentik)
- [ ] Know the project directory structure
- [ ] Be able to add new applications
- [ ] Understand how secrets are managed (Doppler + External Secrets)
- [ ] Know how CI/CD pipelines work
- [ ] Understand Cloudflare Access + Authentik for RBAC

## Related Files

- `business-domain.md` - What the homelab provides
- `business-tech-bridge.md` - How needs map to technical solutions
- `decisions-log.md` - Past infrastructure decisions
