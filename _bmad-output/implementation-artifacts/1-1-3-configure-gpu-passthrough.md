# Story 1.1.3: Configure GPU Passthrough

Status: backlog (low priority - to be implemented later)

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer administrator,
I want GPU passthrough configured on the Proxmox host,
so that I can use the NVIDIA GPU in gaming VMs (e.g. Windows Gaming VM, Epic 6.1).

## Acceptance Criteria

1. [ ] IOMMU enabled in BIOS
2. [ ] VFIO modules loaded in Proxmox
3. [ ] GPU isolated from host (bound to vfio-pci, not nvidia/nouveau on host)
4. [ ] GPU available for VM assignment in Proxmox UI
5. [ ] Passthrough tested with a test VM (create minimal VM, attach GPU, boot and verify GPU visible inside guest)

## Tasks / Subtasks

- [ ] Task 1: Enable IOMMU (AC: #1)
  - [ ] Confirm CPU: AOOSTAR WTR MAX has AMD Ryzen 7 8845HS → use `amd_iommu=on`
  - [ ] Enable IOMMU/VT-d in BIOS if not already enabled
  - [ ] Add kernel parameter: `amd_iommu=on` (or `intel_iommu=on` if Intel) to Proxmox boot config (e.g. GRUB)
  - [ ] Reboot and verify: `dmesg | grep -e DMAR -e IOMMU`
- [ ] Task 2: Load VFIO and isolate GPU (AC: #2, #3)
  - [ ] Ensure VFIO modules load at boot: `vfio`, `vfio_pci`, `vfio_virqfd`
  - [ ] Blacklist host use of GPU: blacklist `nvidia` and `nouveau` (so host does not bind GPU)
  - [ ] Pass GPU to vfio-pci via kernel cmdline or modprobe (e.g. `softdep nvidia pre: vfio-pci` or IDs in `vfio-pci.ids`)
  - [ ] Reboot and verify: `lspci -nnk` shows GPU with driver `vfio-pci`
- [ ] Task 3: Expose GPU to Proxmox VMs (AC: #4)
  - [ ] In Proxmox: add PCI device (hostpci) to a test VM with GPU PCI ID, ROM bar if needed
  - [ ] Document or script the PCI passthrough config for reuse (e.g. Windows Gaming VM later)
- [ ] Task 4: Validate with test VM (AC: #5)
  - [ ] Create a small test VM (e.g. Linux) with GPU passthrough
  - [ ] Boot guest and verify GPU is visible (e.g. `lspci` inside guest)
  - [ ] Remove test VM or keep for regression checks

## Dev Notes

- **Hardware**: AOOSTAR WTR MAX, AMD Ryzen 7 8845HS, NVIDIA GPU. [Source: docs-site/docs/infrastructure/proxmox.md]
- **Architecture**: Proxmox VE is the hypervisor; GPU passthrough is on the **host** (this story). KubeVirt/GPU Operator is a later option (Epic 6.2). [Source: _bmad-output/planning-artifacts/architecture-proxmox-omni.md]
- **Do not change**: Existing Proxmox install (1.1.1), ZFS pool (1.1.2), or Terraform/API (1.1.4). Only kernel params, modules, and PCI passthrough config.
- **Host must not use the GPU**: Blacklist nvidia/nouveau on host so only vfio-pci binds the GPU; no X/Wayland on host using this GPU.

### Project Structure Notes

- Proxmox host is managed manually / Ansible / scripts; no Terraform for kernel params in this story (optional: document in `docs/` or `scripts/proxmox/`).
- Existing doc: `docs-site/docs/infrastructure/proxmox.md` has a short "GPU Passthrough" section (IOMMU check, lspci). Align steps and extend if needed.
- Optional: `scripts/proxmox/post-install.sh` is mentioned as configuring IOMMU; ensure this story’s steps are consistent or integrated there.

### References

- [Source: _bmad-output/planning-artifacts/epics-and-stories-homelab.md] Story 1.1.3 acceptance criteria and technical notes (intel_iommu/amd_iommu, blacklist nouveau/nvidia).
- [Source: _bmad-output/planning-artifacts/architecture-proxmox-omni.md] Proxmox VE decision, GPU for gaming VMs, hardware (NVIDIA GPU).
- [Source: docs-site/docs/infrastructure/proxmox.md] GPU Passthrough checklist, IOMMU and GPU verification commands.
- [Source: docs-site/docs/infrastructure/proxmox.md] Post-install includes IOMMU; keep consistent.

## Dev Agent Record

### Agent Model Used

(To be filled by dev agent)

### Debug Log References

### Completion Notes List

### File List
