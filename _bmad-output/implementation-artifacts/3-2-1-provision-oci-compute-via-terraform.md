# Story 3.2.1: Provision OCI Compute via Terraform

Status: ready-for-dev

## Story

As a developer administrator,
I want Kubernetes nodes on Oracle Cloud
so that I can run family-facing services externally.

## Acceptance Criteria

1. [ ] oci-node-1: 2 OCPU, 12 GB RAM, 64 GB disk (control plane + worker)
2. [ ] oci-node-2: 1 OCPU, 6 GB RAM, 75 GB disk (worker)
3. [ ] VCN and subnet configured
4. [ ] Security lists configured
5. [ ] Static public IP assigned (or ephemeral; document for bootstrap)

## Implementation Summary

- **Terraform** : `terraform/oracle-cloud/` defines:
  - Management VM (oci-mgmt) + **K8s nodes** via `oci_core_instance.k8s_node`.
  - **Talos from first boot** : when `talos_image_id` is set, nodes use the **Omni-generated image** (pre-configured; no user_data). See [Zwindler - Omni Talos Oracle Cloud](https://blog.zwindler.fr/2025/01/04/sideros-omni-talos-oracle-cloud/) and README. Static private IPs: 10.0.1.10, 10.0.1.11. Variable: `talos_image_id` only.
  - Fallback: if `talos_image_id` is empty, nodes use Ubuntu (legacy).
- **CI** : Apply via GitHub Actions **Terraform Oracle Cloud**. For Talos, set `talos_image_id` (e.g. from vars) or apply locally after importing the Omni image.
- **Local** : `task oci:terraform:apply` (with TF_VAR_* or .envrc).

## Tasks / Subtasks

- [ ] Task 1: Verify Terraform plan (AC 1–4)
  - [ ] Run `task oci:terraform:plan` or CI plan; confirm oci-node-1, oci-node-2, VCN, security lists
- [ ] Task 2: Apply Terraform (AC 1–5)
  - [ ] Run apply via CI (recommended) or locally with OCI auth
  - [ ] Confirm outputs: `management_vm`, `k8s_nodes` (if public_ip is null for k8s_nodes, add VNIC data source and output)
- [ ] Task 3: Document node IPs for bootstrap (Story 3.2.2)
  - [ ] Note control plane IP (first node) and worker IPs for Talos bootstrap
  - [ ] See `terraform output k8s_nodes` or `task oci:terraform:output`

## Dev Notes

- **ARM** : VM.Standard.A1.Flex (Always Free). Stay within quota (see workflow quota-check).
- **Outputs** : `outputs.tf` exposes `k8s_nodes` (id, name, public_ip, private_ip). If `public_ip` is null (OCI instance attribute may come from VNIC), add `data "oci_core_vnic_attachments"` / `data "oci_core_vnic"` per node and use in output.
- **Next** : Story 3.2.2 (Bootstrap CLOUD Cluster) uses these IPs for Talos install.

## References

- [Epics & Stories](../planning-artifacts/epics-and-stories-homelab.md) — Story 3.2.1
- [OCI-First Roadmap](../planning-artifacts/oci-first-roadmap.md)
- [terraform/oracle-cloud/README.md](../../terraform/oracle-cloud/README.md)
