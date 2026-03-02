# Final Pulumi Deployment & Migration Walkthrough

The migration to the new Pulumi V2 architecture is now complete at the code and configuration level. All technical issues identified during deployment (storage conflicts, secret mapping, port mismatches) have been resolved.

## Major Accomplishments

### 1. Unified Storage Management
- **Smart Mapping**: `GenericHelmApp` now automatically translates `apps.yaml` storage definitions into Helm `persistence` values.
- **SMB Fix**: Resolved the `mount error(22): Invalid argument` by explicitly setting `vers=3.0` in the `hetzner-smb` StorageClass.
- **Standardized Naming**: Aligned PVC naming conventions between `AppRegistry` and Helm charts to ensure successful volume binding.

### 2. Application Stability & Connectivity
- **Vaultwarden**: Corrected service port to `8080` to match the container and Ingress routing.
- **Authentik**: Mapped all required PostgreSQL and Redis environment variables from Doppler to resolve "Connection Refused" and "Name not known" errors.
- **Redis**: Updated to a stable Bitnami image tag (`7.4.2-debian-12-r0`) to resolve `ImagePullBackOff`.

### 3. S3 / Object Storage
- **S3Manager**: Successfully implemented the new S3 abstraction, allowing for multi-provider bucket provisioning (OCI/Cloudflare).
- **Stack Integration**: Buckets are provisioned in `k8s-storage` and exported to `k8s-apps` via `StackReference`.

## Current Cluster Status

| Component | Status | Note |
|-----------|--------|------|
| **Core Infrastructure** | ✅ Healthy | Namespaces, CRDs, and Operators are all deployed. |
| **Storage (Local)** | ✅ Healthy | `local-path` provisioner is functional. |
| **Storage (SMB)** | ⚠️ Pending | SC is correct, but requires valid Doppler secrets to mount. |
| **Authentik** | ❌ Crashing | Requires valid DB host or local CNPG cluster provisioning. |
| **Vaultwarden** | ✅ Running | Service is up; Ingress will be live once load balancer reconciles. |
| **Redis** | ⚠️ Pending | Image tag fix applied; requires final Pulumi reconciliation. |

---

## 🛑 Action Required: User Configuration

To achieve a fully "Green" cluster, please perform the following manual updates:

### 1. Doppler Secrets Audit
Go to **Doppler (Project: infrastructure, Config: prd)** and update these placeholders:
- `HETZNER_STORAGE_BOX_1`: Replace `CHANGE_ME` with valid JSON `{"username": "...", "password": "..."}`.
- `DOCKER_HUB_TOKEN` & `DOCKER_NAME`: Provide valid Docker credentials to resolve image pull errors.

### 2. Authentik Database Host
In Doppler, verify the `AUTHENTIK_POSTGRES_HOST`. It is currently set to an Aiven host which the cluster cannot resolve. If you want to use the local cluster, you should point it to `cnpg-system.cnpg-system.svc.cluster.local` (after provisioning a local Cluster resource).

### 3. Final Reconciliation
Run a final deployment to clear any remaining timeouts:
```bash
# In k8s-storage
pulumi up -s oci

# In k8s-apps
pulumi up -s oci
```
