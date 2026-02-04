# Story 1.3.4: Configure MachineClasses

Status: ready-for-dev

## Story

As a developer administrator,
I want MachineClass definitions for node profiles,
so that I can declaratively define node specifications.

## Acceptance Criteria

1. [ ] `control-plane` MachineClass defined
2. [ ] `worker` MachineClass defined
3. [ ] `gpu-worker` MachineClass defined (for future)
4. [ ] MachineClasses stored in `omni/machine-classes/`

## Technical Notes

- Define CPU, RAM, storage, labels
- Reference in ClusterTemplate
- Omni docs: [Create a Machine Class](https://docs.siderolabs.com/omni/omni-cluster-setup/create-a-machine-class)

## Tasks / Subtasks

- [ ] Task 1: Create control-plane MachineClass in Omni (AC #1)
  - [ ] In Omni UI or via omnictl/API: create MachineClass with name `control-plane` (or `omni-homelab-controlplane`)
  - [ ] Document spec in `omni/machine-classes/README.md` (CPU, RAM, disk, labels)
- [ ] Task 2: Create worker MachineClass (AC #2)
  - [ ] Create MachineClass `worker` with specs for standard workers
  - [ ] Document in README
- [ ] Task 3: Create gpu-worker MachineClass for future use (AC #3)
  - [ ] Create placeholder MachineClass `gpu-worker` (optional labels for GPU nodes)
- [ ] Task 4: Store definitions in repo (AC #4)
  - [ ] Keep `omni/machine-classes/` as source of truth for specs (YAML or README)
  - [ ] Reference MachineClass names in ClusterTemplate when creating clusters

## Dev Notes

- **Omni** : MachineClasses are created in Omni (UI or API). The repo holds the *spec* and naming convention.
- **ClusterTemplate** : Uses `machineClass.name` and `machineClass.size` (see siderolabs/contrib examples).
- **Naming** : Align with existing clusters: `dev`, `cloud` (cluster names); MachineClass names: `control-plane`, `worker`, `gpu-worker`.

## References

- [Epics & Stories](../planning-artifacts/epics-and-stories-homelab.md) — Story 1.3.4
- [Omni: Create a Machine Class](https://docs.siderolabs.com/omni/omni-cluster-setup/create-a-machine-class)
- [Contrib: cluster-template example](https://github.com/siderolabs/contrib/blob/main/examples/omni/infra/cluster-template.yaml)
