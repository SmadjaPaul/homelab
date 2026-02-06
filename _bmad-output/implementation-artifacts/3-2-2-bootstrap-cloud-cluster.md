# Story 3.2.2: Bootstrap CLOUD Cluster

Status: ready-for-dev

## Story

As a developer administrator,
I want the Oracle Cloud Kubernetes cluster bootstrapped
so that I can run external services.

## Acceptance Criteria

1. [ ] Talos installed on OCI nodes
2. [ ] Cluster bootstrapped
3. [ ] Cluster registered with Omni
4. [ ] ArgoCD syncing from Git (optional in this story)
5. [ ] Cilium CNI operational (optional in this story)

## Implementation Summary

- **Approche alignée avec [Zwindler (Omni + Talos sur OCI)](https://blog.zwindler.fr/2025/01/04/sideros-omni-talos-oracle-cloud/)** : l’image Talos est **générée par Omni** (préconfigurée avec les credentials). On la télécharge depuis l’UI Omni, on l’importe dans OCI comme custom image, on définit `talos_image_id` dans Terraform. Les VMs créées avec cette image bootent en Talos et **s’enrôlent dans Omni au premier boot** ; pas de user_data ni de secrets dans Terraform.
- **Terraform** (Story 3.2.1) : quand `talos_image_id` est défini, les nœuds K8s utilisent cette image (metadata vide). IPs privées fixes : 10.0.1.10, 10.0.1.11. Voir `terraform/oracle-cloud/README.md`.
- **Talos configs** : `talos/controlplane-cloud.yaml` et `talos/worker-cloud.yaml` restent en référence (config manuelle ou autre flux) ; pour OCI + Omni, l’image Omni suffit.

## Tasks / Subtasks

- [ ] Task 1: Prepare Talos configs for CLOUD (AC #1–2)
  - [ ] Set control plane endpoint and node IPs (from Terraform output) in `controlplane-cloud.yaml` and `worker-cloud.yaml`
  - [ ] Generate cluster secrets: `talosctl gen secrets`
  - [ ] Replace `<CLUSTER_SECRET>` and endpoint / certSANs with actual values
- [ ] Task 2: Install Talos on OCI nodes (AC #1)
  - [ ] Boot oci-node-1 from Talos installer (ISO or image); run `talosctl apply-config` for control plane
  - [ ] Boot oci-node-2; run `talosctl apply-config` for worker
  - [ ] Run `talosctl bootstrap` on control plane
- [ ] Task 3: Register cluster in Omni (AC #3)
  - [ ] Create cluster "cloud" in Omni (UI or `task oci:omni:create`), get join token
  - [ ] VMs boot with Omni image and auto-enroll; add machines to cluster from Omni UI
- [ ] Task 4: Verify ArgoCD / Cilium (AC #4–5)
  - [ ] Install ArgoCD on CLOUD if not done via Omni; deploy Cilium (Wave 0)

## Dev Notes

- **Network** : OCI VCN 10.0.1.0/24. Control plane = first node IP, worker = second. Update configs with real IPs from `terraform output -json k8s_nodes`.
- **Omni** : Create cluster in Omni UI, download Oracle image, import to OCI, set `talos_image_id`. No join token in Terraform.
- **Configs** : `talos/controlplane-cloud.yaml`, `talos/worker-cloud.yaml` — no ZFS; install disk typically `/dev/sda` on OCI.

## References

- [Epics & Stories](../planning-artifacts/epics-and-stories-homelab.md) — Story 3.2.2
- [OCI-First Roadmap](../planning-artifacts/oci-first-roadmap.md)
- [talos/README.md](../../talos/README.md)
- [docs-site/docs/infrastructure/kubernetes.md](../../docs-site/docs/infrastructure/kubernetes.md) (Omni configuration)
