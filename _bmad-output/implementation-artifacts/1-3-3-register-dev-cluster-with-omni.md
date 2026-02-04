# Story 1.3.3: Register DEV Cluster with Omni

Status: in-progress

## Implementation Summary

- ✅ Story file created
- ✅ Documentation created: `docs/omni-register-cluster.md`
- **CLOUD (OCI)** : utiliser l’image Talos générée par Omni (créer cluster dans UI, télécharger image Oracle, import OCI, `talos_image_id`). Les VMs s’enrôlent au premier boot. Voir [Zwindler](https://blog.zwindler.fr/2025/01/04/sideros-omni-talos-oracle-cloud/).
- **DEV (Proxmox)** : créer le cluster dans l’UI Omni, ajouter la section Omni (url, joinToken) dans `talos/controlplane.yaml` et `talos/worker.yaml`, puis `talosctl apply-config`. Docs : `docs/omni-register-cluster.md`.

## Story

As a developer administrator,
I want the DEV cluster registered in Omni,
so that I can manage it through the Omni dashboard.

## Acceptance Criteria

1. [ ] Omni agent installed on DEV cluster
2. [ ] Cluster visible in Omni UI
3. [ ] Node health displayed
4. [ ] Kubeconfig downloadable from Omni
5. [ ] Cluster upgrades manageable via Omni

## Tasks / Subtasks

- [ ] Task 1 (CLOUD): Create cluster in Omni UI, download Oracle image, import to OCI, set `talos_image_id`, terraform apply. VMs auto-enroll.
- [ ] Task 2 (DEV): Create cluster in Omni UI, copy join token. Add Omni section to `talos/controlplane.yaml` and `talos/worker.yaml`, then `talosctl apply-config`.
- [ ] Task 3: Verify cluster registration in Omni UI (AC: #2, #3)
  - [ ] Check Omni UI shows DEV cluster
  - [ ] Verify all nodes (control-plane + worker) are visible
  - [ ] Check node health status is displayed correctly
  - [ ] Verify cluster state is "Ready"
- [ ] Task 4: Test kubeconfig download (AC: #4)
  - [ ] Download kubeconfig from Omni UI
  - [ ] Test kubectl access: `kubectl get nodes`
  - [ ] Verify cluster context works correctly
- [ ] Task 5: Verify cluster management capabilities (AC: #5)
  - [ ] Check that cluster upgrades are visible/manageable in Omni UI
  - [ ] Verify cluster configuration can be viewed/edited
  - [ ] Test any available cluster management features

## Dev Notes

- **Omni Deployment**: Omni is already deployed on OCI VM via `docker/oci-mgmt/docker-compose.yml` (Story 1.3.2 done)
- **Omni Endpoint**: `http://omni:8080` (internal) or `https://omni.smadja.dev` (via Cloudflare Tunnel)
- **DEV Cluster**: Talos cluster already bootstrapped (Story 1.2.2 done)
- **Cluster Name**: Use `dev` or `talos-dev` as cluster identifier
- **Bi-directional connectivity**: Ensure DEV cluster nodes can reach Omni endpoint (may require firewall rules or VPN)

### Project Structure Notes

- Talos configs: `talos/controlplane.yaml`, `talos/worker.yaml`
- Omni deployment: `docker/oci-mgmt/docker-compose.yml`
- Documentation: Update `docs-site/docs/infrastructure/kubernetes.md` with Omni registration steps

### References

- [Source: _bmad-output/planning-artifacts/epics-and-stories-homelab.md] Story 1.3.3 acceptance criteria and technical notes
- [Source: docker/oci-mgmt/README.md] Omni deployment details
- [Source: docker/oci-mgmt/docker-compose.yml] Omni configuration
- [Omni Documentation: Register machines with Omni](https://docs.siderolabs.com/omni/omni-cluster-setup/registering-machines/register-machines-with-omni)
- [Omni Documentation: Create a Cluster](https://docs.siderolabs.com/omni/getting-started/create-a-cluster)

## Dev Agent Record

### Agent Model Used

(To be filled by dev agent)

### Debug Log References

### Completion Notes List

### File List
