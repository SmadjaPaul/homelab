<!-- Context: infrastructure | Priority: high | Version: 2.0 | Updated: 2026-03-13 -->

# Infrastructure & IaC

## Cloud Providers

| Provider | Usage |
|----------|-------|
| **OCI (Oracle Cloud)** | Primary Kubernetes cluster (OKE), Block Storage, Object Storage (S3) |
| **Hetzner** | Storage Boxes (SMB) for bulk data (media, files) |
| **Cloudflare** | DNS, Tunnel (cloudflared), R2 (optional S3) |

## Terraform vs Pulumi

- **Terraform (`/terraform`)**: Primitive cloud resources - OCI Compute, VCN networking.
- **Pulumi (`/kubernetes-pulumi`)**: Entire K8s cluster, Helm charts, DNS, IDP structures.

## Storage Strategy (OCI Free Tier - 200GB)

| Tier | Storage Type | Usage | Limit |
|------|-------------|-------|-------|
| **Tier 1** | OCI Block Storage (oci-bv) | PostgreSQL databases (homelab-db) | 100GB max |
| **Tier 2** | Local Path CSI | Redis, caches, temp data | Ephemeral |
| **Tier 3** | Hetzner Storage Box (SMB) | Media, Nextcloud data, archives | 1TB+ |

**Note**: OCI Free Tier = 200GB total. Current: 100GB boot + 100GB CNPG = 100% used.

## Secrets Management (Doppler)

**NEVER COMMIT SECRETS IN PLAIN TEXT.**

1. **Doppler** is the central source for all secrets (API keys, passwords).
2. **External Secrets Operator (ESO)** syncs Doppler secrets to K8s.
3. **Fail-Fast**: At `pulumi preview`, AppRegistry validates all secrets exist in Doppler before creating any K8s resources.

### Adding Secrets

```bash
# 1. Add to Doppler
doppler secrets set MYAPP_API_KEY="secret" -p homelab -c prd

# 2. Reference in apps.yaml
secrets:
  - name: myapp-creds
    keys:
      API_KEY: MYAPP_API_KEY

# 3. Deploy
cd kubernetes-pulumi/k8s-apps && pulumi up
```

## S3 Buckets (Multi-Provider)

Configured in `apps.yaml` with provider-agnostic drivers:

| Driver | Provider | Notes |
|--------|----------|-------|
| `OciS3Driver` | Oracle Cloud | Always-free 20GB |
| `CloudflareR2Driver` | Cloudflare R2 | Zero egress fees |
| `GenericS3Driver` | Any S3 endpoint | RustFS, MinIO, Garage |
