# Talos Single-Node Cluster (Home Server) Recommendations

## Hardware Context
- **Total Specs:** 58GB RAM, 10 CPU Cores.
- **Goal:** Deploy the first services onto a local Talos cluster (likely running under Proxmox or bare metal).

## Architecture Recommendations

### 1. Proxmox VMs vs Baremetal
Since you have 58GB RAM and 10 CPUs, running Proxmox as the base OS and Talos as a VM is highly recommended. It gives you incredible flexibility:
- You can allocate `4-6 CPUs` and `32GB-40GB RAM` to your Talos VM.
- The remaining resources (18-26GB RAM, 4-6 CPUs) can be used for LXC containers or other VMs (e.g., TrueNAS for storage, Ubuntu for Docker testbeds).
- Backups of the Talos VM can be handled easily via Proxmox Backup Server.

### 2. Storage Strategy
Single-node Kubernetes clusters often struggle with complex Distributed Storage (like Longhorn or Ceph) due to lack of quorum.
- **Default/Simplest:** `local-path-provisioner`. Ideal for a single node. Talos natively supports it, and it writes directly to the disk without network overhead.
- **Alternative (ZFS):** If you pass through a whole disk or ZFS array from Proxmox to Talos, you can use OpenEBS LocalPV ZFS.
- **Recommendation:** Stick to `local-path-provisioner` on a large virtual disk provided by Proxmox.

### 3. Talos Configuration (SNc - Single Node Cluster)
When generating the Talos machine configuration, ensure you specify that it's a single node cluster so it doesn't wait indefinitely for other control-plane nodes to join:
```bash
talosctl gen config single-node-cluster https://<IP>:6443
```
- Or if using Sidero Omni (as per your Roadmap), configure the cluster topology in Omni to be exactly 1 Control Plane node with allowing scheduling of workloads on the control-plane.

### 4. Workload Scheduling
By default, Kubernetes does not schedule application pods on Control Plane nodes.
In a single-node setup, you **must** remove the NoSchedule taint:
```yaml
cluster:
  allowSchedulingOnControlPlanes: true
```

### 5. Ingress and Network
- Since you are using Cloudflare Tunnels (`cloudflared`), you do not need strictly defined LoadBalancers (like MetalLB) for inbound traffic unless you want local access (e.g. `*.home.smadja.dev` resolving locally via a local DNS like PiHole or CoreDNS).
- If you plan to access services purely locally without going through Cloudflare, deploy `MetalLB` and `Traefik` to expose standard IPs on your local network.
