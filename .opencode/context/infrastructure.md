<!-- Context: infrastructure | Priority: high | Version: 1.1 | Updated: 2026-03-06 -->

# Infrastructure & IaC

## Architecture
The foundation of the homelab relies on **OCI (Oracle Cloud Infrastructure)** for the primary Kubernetes cluster (OKE) and **Hetzner Storage Boxes** for bulk storage.

## Terraform vs Pulumi
- **Terraform (`/terraform`)**: Used strictly for primitive cloud resources:
  - OCI Compute instances and Base VCN networking.
- **Pulumi (`/kubernetes-pulumi`)**: Used for the entirety of the Kubernetes cluster, configuration, Helm charts, DNS records, and IDP structures.

## Secrets Management (Doppler)
**DO NOT COMMIT SECRETS IN PLAIN TEXT.**
- **Doppler** is the single source of truth for all environment variables, API tokens, and passwords.
- Secret injection into Kubernetes is orchestrated securely by the **External Secrets Operator (ESO)**.
- Pre-flight secret validation guarantees that Pulumi will fail immediately if attempting to deploy an application whose secrets are missing in Doppler.
