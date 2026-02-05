# Omni MachineClasses

This directory documents the **MachineClass** definitions used for Omni cluster templates (DEV, CLOUD). The actual classes are created in Omni (UI or API); this repo is the source of truth for naming and intended specs.

## Naming convention

| MachineClass name   | Role         | Use in clusters |
|--------------------|-------------|------------------|
| `control-plane`    | Control plane nodes | dev, cloud |
| `worker`           | Worker nodes        | dev, cloud |
| `gpu-worker`       | GPU workers (future) | dev (optional) |

## Intended specs (documentation)

- **control-plane** : 2 CPU, 4 GB RAM (DEV) ; 2 OCPU, 12 GB (CLOUD OCI). Disk per Omni/default.
- **worker** : 2 vCPU, 4 GB (DEV) ; 1–2 OCPU, 6–12 GB (CLOUD). Disk per Omni/default.
- **gpu-worker** : Reserved for future GPU passthrough nodes (labels, no hard spec yet).

## Creating MachineClasses in Omni

1. Open Omni UI → Machine Classes (or use `omnictl` if available).
2. Create each class with the names above and the desired CPU/RAM/disk.
3. Reference them in ClusterTemplate when creating a cluster, e.g.:

```yaml
# Example structure (see Omni docs for exact schema)
kind: ControlPlane
machineClass:
  name: control-plane
  size: 1   # or 3 for HA
---
kind: Workers
machineClass:
  name: worker
  size: 1   # or unlimited
```

## References

- [Omni: Create a Machine Class](https://docs.siderolabs.com/omni/omni-cluster-setup/create-a-machine-class)
- [OCI-First Roadmap](../../_bmad-output/planning-artifacts/oci-first-roadmap.md) — Phase A includes 1.3.4
