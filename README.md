# Homelab v1.0

![Platform Status](https://img.shields.io/badge/Status-V1.0_Stable-success)
![Infrastructure](https://img.shields.io/badge/Infrastructure-Pulumi_Python-blue)
![Identity](https://img.shields.io/badge/Identity-Authentik_OIDC-orange)

Welcome to the **Homelab V1.0**.

This project maintains a highly available, data-driven Kubernetes infrastructure split between a **Cloud Hub (OCI)** and a **Home Spoke (Proxmox/Talos)**. The platform provides secure, Zero-Trust access to all self-hosted and business services.

## 🌟 Key Features of V1.0

- **Data-Driven Architecture**: All applications are declaratively managed through a single `apps.yaml`. No need to write complex Python code for generic apps.
- **Fail-Fast Secrets**: Deep integration with [Doppler](https://doppler.com). The system verifies all required secrets before any Kubernetes resource is deployed.
- **SSO Everywhere**: [Authentik](https://goauthentik.io/) is the central Identity Provider. It natively proxies internal applications and provides OIDC authentication for compatible apps (like Navidrome and Vaultwarden).
- **GitOps & IaC**: The entire cluster setup, namespaces, storage, networking, and apps are managed across three logical [Pulumi](https://pulumi.com/) stacks (`k8s-core`, `k8s-storage`, `k8s-apps`).
- **Zero Trust Exposure**: No public inbound ports. Everything flows securely through Cloudflare Tunnels dynamically configured by Pulumi.

## 📚 Documentation

The documentation has been consolidated to reflect the V1.0 state:

- 🏛️ **[Architecture](docs/ARCHITECTURE.md)**: Deep dive into the Pulumi ComponentResources, AppLoaders, and the deployment sequence.
- 🚀 **[Deployment](docs/DEPLOYMENT.md)**: How to initialize the cluster and deploy the 3 Pulumi stacks.
- 🌐 **[Networking & Access](docs/NETWORKING.md)**: Explains the Zero Trust flow via Cloudflare and Authentik Outposts.
- 📦 **[Service Catalog](docs/SERVICE-CATALOG.md)**: Full list of V1 actively-running services and planned apps.
- 🗺️ **[Roadmap](ROADMAP.md)**: The next steps and future V2 features for the lab.

## 🛠️ Tech Stack

- **Cloud/Infra**: Oracle Cloud (OKE), Proxmox VE, Hetzner Storage Boxes.
- **Operations**: Pulumi (Python), Doppler, GitHub Actions.
- **Identity & Networking**: Cloudflare Tunnels, Authentik, Envoy Gateway, External-DNS.
- **State Management**: CloudNativePG (PostgreSQL), Redis.

## 🚀 Quick Start

Ensure you have `pulumi`, `doppler`, and `kubectl` installed.

```bash
# 1. Login to Doppler to fetch infrastructure secrets
doppler login

# 2. Deploy Core Foundation
cd kubernetes-pulumi/k8s-core
pulumi up

# 3. Deploy Storage & Databases
cd ../k8s-storage
pulumi up

# 4. Deploy Apps & Services
cd ../k8s-apps
pulumi up
```
For detailed instructions, see the **[Deployment Guide](docs/DEPLOYMENT.md)**.
