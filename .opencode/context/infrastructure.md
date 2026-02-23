<!-- Context: infrastructure | Priority: high | Version: 1.0 | Updated: 2026-02-21 -->

# Infrastructure & IaC

## Architecture
The foundation of the homelab relies on **OCI (Oracle Cloud Infrastructure)** for the primary Kubernetes cluster (OKE), utilizing the generous Always Free tier.

## Terraform (`/terraform`)
Terraform is used strictly for stateful and structural cloud resources:
- **OCI Resources**: Compute, networking, and the OKE cluster.
- **Cloudflare**: DNS management, Cloudflare Tunnels, and Zero Trust settings.
- **Authentik**: IDP infrastructure configuration.

### Providers & Workspaces
- Scripts and modules are split logically (e.g., `terraform/oracle-cloud`, `terraform/cloudflare`, `terraform/authentik`).
- If debugging provider issues (such as the Authentik provider bug in Phase 2), navigate to the specific module directory and execute `terraform plan` to understand state mismatches.

## Secrets Management (Doppler)
**DO NOT COMMIT SECRETS IN PLAIN TEXT.**
- **Doppler** is the single source of truth for all environment variables, tokens, and passwords.
- **Projects & Environments**: There is currently only ONE project named `infrastructure` and ONE environment `prd` used across all services.
- Secret injection into Kubernetes is handled by **External Secrets Operator (ESO)** which fetches them from Doppler.
- The only manual step required during cluster bootstrapping is creating the initial `doppler-credentials` secret.
