<!-- Context: project-intelligence/decisions | Priority: high | Version: 3.0 | Updated: 2026-02-19 -->

# Decisions Log

> Record major architectural and business decisions with full context.

## Quick Reference

- **Purpose**: Document decisions so future understanding is clear
- **Format**: Each decision as a separate entry
- **Status**: Decided | Pending | Under Review | Deprecated

---

## OCI as Cloud Provider

**Date**: 2024-01
**Status**: Decided

### Context
Needed a cloud provider for Kubernetes that offers free tier and good documentation.

### Decision
Use Oracle Cloud Infrastructure (OCI) with Oracle Kubernetes Engine (OKE).

### Rationale
- Free tier available
- Good Kubernetes support
- Professional documentation

### Alternatives Considered
| Alternative | Pros | Cons | Why Rejected? |
|-------------|------|------|---------------|
| AWS EKS | Popular | Expensive | Cost concerns |
| GCP GKE | Good docs | Limited free tier | Not enough free resources |
| Hetzner | Cheap | Less K8s integration | Prefer managed K8s |

---

## Flux for All Kubernetes Resources

**Date**: 2024-01
**Status**: Decided

### Context
Needed GitOps tool to manage all Kubernetes resources.

### Decision
Use Flux to manage ALL Kubernetes resources (not just apps).

### Rationale
- Single source of truth for K8s state
- Manages HelmReleases, Kustomizations, ExternalSecrets
- Namespace-level RBAC
- Source configuration

---

## Terraform for Infrastructure Only

**Date**: 2024-01
**Status**: Decided

### Context
Needed to clarify what Terraform manages vs Flux.

### Decision
Terraform manages cloud infrastructure only; Flux manages all Kubernetes resources.

### Scope
- **Terraform**: OCI (compute, network, OKE), Cloudflare, Authentik deployment
- **Flux**: All Kubernetes resources (namespaces, HelmReleases, ExternalSecrets, RBAC)

### Rationale
- Clear separation of concerns
- GitOps for K8s (Flux is better suited)
- IaC for cloud (Terraform)

---

## Doppler for Secrets

**Date**: 2024-06
**Status**: Decided

### Context
Needed secret management that integrates with Kubernetes.

### Decision
Use Doppler with External Secrets Operator (synced by Flux).

### Rationale
- Team collaboration
- Audit logs
- Easy sync to cluster via External Secrets Operator

### Alternatives Considered
| Alternative | Pros | Cons | Why Rejected? |
|-------------|------|------|---------------|
| Vault | Enterprise features | Complex setup | Overkill for homelab |

---

## Cloudflare Access + Authentik

**Date**: 2026-02
**Status**: Decided

### Context
Need secure access to services with RBAC capabilities.

### Decision
Use Authentik as Identity Provider (IDP) with Cloudflare Access for zero-trust access control.

### Networking Flow
```
Internet → Cloudflare → Cloudflare Tunnel → Kubernetes Services
                    ↓
              Cloudflare Access (Authentik OAuth)
                    ↓
              Authentik (IDP)
```

### Rationale
- Cloudflare Access free tier
- Authentik open source
- RBAC via Cloudflare Access Policies
- Map Authentik groups to access levels

---

## Kustomize over KCL

**Date**: 2026-02
**Status**: Decided

### Context
Originally used KCL for type-safe configuration.

### Decision
Use Kustomize with standard YAML.

### Rationale
- Simpler tooling
- Wider community support
- Native Flux support

### Alternatives Considered
| Alternative | Pros | Cons | Why Rejected? |
|-------------|------|------|---------------|
| KCL | Type safety | Extra dependency | Not worth complexity |
| CUE | Unification | Steep learning curve | Too complex |
