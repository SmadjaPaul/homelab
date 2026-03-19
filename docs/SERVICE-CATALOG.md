# Service Catalog (auto-generated from apps.yaml)

> Last updated: 2026-03-24 — Edit `apps.yaml`, then run `scripts/update-context.py`

## Protected Apps (Authentik SSO)

| Name | Namespace | URL | Helm Chart | Mode |
|------|-----------|-----|------------|------|
| **nextcloud** | `productivity` | - | `nextcloud` | protected |
| **paperless-ngx** | `productivity` | - | `paperless-ngx` | protected |
| **immich** | `photography` | - | `immich` | protected |
| **romm** | `gaming` | - | `romm` | protected |
| **homepage** | `homelab` | - | `app-template` | protected |
| **navidrome** | `music` | - | `app-template` | protected |
| **slskd** | `music` | - | `app-template` | protected |
| **audiobookshelf** | `music` | - | `app-template` | protected |

## Public Apps

| Name | Namespace | URL | Helm Chart | Mode |
|------|-----------|-----|------------|------|
| **open-webui** | `ai` | - | `open-webui` | public |
| **authentik** | `authentik` | - | `authentik` | public |
| **vaultwarden** | `vaultwarden` | - | `vaultwarden` | public |

## Internal / Infrastructure Apps

| Name | Namespace | URL | Helm Chart | Mode |
|------|-----------|-----|------------|------|
| **envoy-ai-gateway** | `observability` | - | `gateway-helm` | internal |
| **kube-prometheus-stack** | `observability` | - | `kube-prometheus-stack` | internal |
| **promtail** | `observability` | - | `promtail` | internal |
| **cnpg-system** | `cnpg-system` | - | `cloudnative-pg` | internal |
| **redis** | `storage` | - | `redis-ha` | internal |
| **external-secrets** | `external-secrets` | - | `external-secrets` | internal |
| **cert-manager** | `cert-manager` | - | `cert-manager` | internal |
| **envoy-gateway** | `envoy-gateway` | - | `gateway-helm` | internal |
| **cloudflared** | `cloudflared` | - | `cloudflare-tunnel-remote` | internal |
| **external-dns** | `external-dns` | - | `external-dns` | internal |
| **local-path-provisioner** | `kube-system` | - | `local-path-provisioner` | internal |
| **csi-driver-smb** | `kube-system` | - | `csi-driver-smb` | internal |

## S3 Buckets

| Name | Provider | Purpose | Tier |
|------|----------|---------|------|
| `velero-backups` | oci | backup | InfrequentAccess |
| `homelab-db-backups` | oci | backup | InfrequentAccess |
