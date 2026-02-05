# Omni MachineClasses (IaC)

**MachineClass** definitions for Omni cluster templates (DEV, CLOUD). Apply with **omnictl** — no UI needed.

## Naming convention

| MachineClass name   | Role         | Use in clusters |
|---------------------|--------------|------------------|
| `control-plane`    | Control plane nodes | dev, cloud |
| `worker`           | Worker nodes        | dev, cloud |
| `gpu-worker`       | GPU workers (future) | dev (optional) |

## Intended specs (reference)

- **control-plane** : 2 CPU, 4 GB RAM (DEV) ; 2 OCPU, 12 GB (CLOUD OCI). Disk per Omni/default.
- **worker** : 2 vCPU, 4 GB (DEV) ; 1–2 OCPU, 6–12 GB (CLOUD). Disk per Omni/default.
- **gpu-worker** : Reserved for future GPU passthrough nodes (labels, no hard spec yet).

## Apply via omnictl (IaC)

1. **Install & configure omnictl** (see [Install and Configure Omnictl](https://omni.siderolabs.com/how-to-guides/install-and-configure-omnictl)):
   - Endpoint: `https://omni.smadja.dev` (Authentik protects the UI; omnictl may need token or SAML).
   - Self-hosted: use the same URL; ensure TLS and auth are set.

2. **Apply all MachineClasses** (from repo root):
   ```bash
   omnictl apply -f omni/machine-classes/all.yaml
   ```
   Or apply individually: `control-plane.yaml`, `worker.yaml`, `gpu-worker.yaml`.

3. **Create cluster from template** (optional; cluster can also be created in UI once):
   ```bash
   omnictl apply cluster -f omni/clusters/cluster-dev.yaml
   ```
   Adjust Talos/Kubernetes versions in `omni/clusters/cluster-dev.yaml` to match your Omni.

## Fallback: UI

If omnictl is not configured (e.g. auth via Authentik only), create the MachineClasses in Omni UI → Machine Classes with the same names (`control-plane`, `worker`, `gpu-worker`). Cluster creation can still be done in UI; join token / image download then used as in [omni-register-cluster.md](../../docs/omni-register-cluster.md).

## References

- [Omni: Create a Machine Class](https://docs.siderolabs.com/omni/omni-cluster-setup/create-a-machine-class)
- [Omni: Cluster Templates](https://omni.siderolabs.com/docs/reference/cluster-templates/)
- [OCI-First Roadmap](../../_bmad-output/planning-artifacts/oci-first-roadmap.md) — Phase A includes 1.3.4
