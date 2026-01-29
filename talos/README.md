# Talos Linux Configuration

This directory contains Talos Linux machine configuration files for the homelab infrastructure.

## Overview

Talos Linux is an immutable, secure operating system optimized for Kubernetes. It provides:
- API-only management (no SSH by default)
- Immutable filesystem
- Atomic updates
- Minimal OS overhead (~200-300MB)
- Built-in Kubernetes standard

## Hardware

- **Server**: AOOSTAR WTR MAX 8845
- **RAM**: 64GB
- **Storage**: 1TB SSD (boot), 2x 20TB HDD (data)
- **Network**: Gigabit Ethernet

## Files

- `controlplane.yaml` - Control plane node configuration
- `worker.yaml` - Worker node configuration (template for future expansion)
- `patches/` - System extensions and patches

## Installation Procedure

### Prerequisites

1. Download Talos Linux ISO from [releases page](https://github.com/siderolabs/talos/releases)
2. Create bootable USB drive or prepare ISO for IP KVM
3. Access IP KVM for out-of-band management

### Step 1: Generate Cluster Secrets

```bash
talosctl gen secrets -o talos-secrets.yaml
```

**⚠️ IMPORTANT**: Store `talos-secrets.yaml` securely. This file contains cluster secrets and should NOT be committed to Git.

### Step 2: Generate Machine Configuration

```bash
# Generate control plane config
talosctl gen config homelab-cluster https://192.168.1.100:6443 \
  --with-secrets talos-secrets.yaml \
  --output-dir talos/

# Or use the provided templates and update cluster secret
```

### Step 3: Customize Configuration

1. Update network settings in `controlplane.yaml`:
   - IP address (currently: 192.168.1.100)
   - Gateway (currently: 192.168.1.1)
   - DNS servers

2. Update disk selection:
   - Control plane: `/dev/sda` (1TB SSD)
   - Verify disk paths with: `lsblk` or `fdisk -l`

3. Update cluster secret:
   - Replace `<CLUSTER_SECRET>` with actual secret from `talos-secrets.yaml`

### Step 4: Install Talos Linux

#### Option A: Using ISO Image

1. Boot from Talos Linux ISO
2. Apply configuration:

```bash
talosctl apply-config \
  --insecure \
  --nodes 192.168.1.100 \
  --file talos/controlplane.yaml
```

#### Option B: Using Boot-to-Talos (Recommended)

```bash
talosctl image download --arch amd64
talosctl install --config talos/controlplane.yaml
```

### Step 5: Configure talosctl

```bash
# Generate kubeconfig
talosctl kubeconfig \
  --nodes 192.168.1.100 \
  --output kubeconfig

# Configure talosctl
export TALOSCONFIG=./talosconfig
export KUBECONFIG=./kubeconfig
```

### Step 6: Verify Installation

```bash
# Check Talos version
talosctl version --nodes 192.168.1.100

# Check node status
talosctl get nodes

# Check hardware resources
talosctl get resources --nodes 192.168.1.100

# Verify Kubernetes cluster
kubectl get nodes
kubectl get pods --all-namespaces
```

## Network Configuration

### Current Settings

- **Control Plane IP**: 192.168.1.100/24
- **Gateway**: 192.168.1.1
- **DNS**:
  - Primary: 192.168.1.1 (Pi-hole - to be configured)
  - Fallback: 1.1.1.1, 8.8.8.8

### Changing Network Configuration

1. Edit `controlplane.yaml` or `worker.yaml`
2. Apply configuration:

```bash
talosctl apply-config \
  --nodes <NODE_IP> \
  --file talos/controlplane.yaml
```

3. Reboot node:

```bash
talosctl reboot --nodes <NODE_IP>
```

## API Access

### Generate Client Configuration

```bash
talosctl config add homelab \
  --nodes 192.168.1.100 \
  --ca talos/ca.crt \
  --crt talos/admin.crt \
  --key talos/admin.key
```

### Using talosctl

```bash
# Set context
talosctl config set homelab

# Get node information
talosctl get nodes

# Get resources
talosctl get resources

# View logs
talosctl logs <service>
```

## IP KVM Access

### Access Information

- **IP Address**: [To be configured when hardware is available]
- **Port**: [To be configured]
- **Credentials**: [To be stored securely, not in Git]

### Usage

1. Access IP KVM web interface
2. Use remote console for:
   - Initial installation
   - BIOS/UEFI configuration
   - Troubleshooting when OS is down
   - Out-of-band management

## Hardware Verification

### Verify Resources

```bash
# Check RAM
talosctl get resources --nodes <NODE_IP> | grep memory

# Check disks
talosctl get disks --nodes <NODE_IP>

# Check network interfaces
talosctl get links --nodes <NODE_IP>
```

### Expected Hardware

- **RAM**: 64GB (should show ~64GB available)
- **SSD**: 1TB (boot disk)
- **HDD**: 2x 20TB (data disks, to be configured in ZFS story)

## System Extensions

Talos uses system extensions for additional functionality:

- **ZFS Extension**: `ghcr.io/siderolabs/zfs:latest`
  - Required for ZFS storage pool (Story 1.2)
  - Loaded via `systemExtensions` in machine config

## Updates

### Check for Updates

```bash
talosctl upgrade --nodes <NODE_IP> --check
```

### Apply Updates

```bash
talosctl upgrade --nodes <NODE_IP> --to <VERSION>
```

### Automatic Updates

Configure automatic updates via machine configuration (to be implemented in Story 2.5).

## Troubleshooting

### Node Not Accessible

1. Check IP KVM access
2. Verify network configuration
3. Check firewall rules
4. Verify Talos API is running:

```bash
talosctl health --nodes <NODE_IP>
```

### Configuration Not Applied

1. Verify YAML syntax:

```bash
talosctl validate --config talos/controlplane.yaml
```

2. Check for errors:

```bash
talosctl get events --nodes <NODE_IP>
```

### Boot Issues

1. Access IP KVM
2. Check boot order in BIOS/UEFI
3. Verify disk is detected
4. Check boot logs via IP KVM console

### Network Issues

1. Verify network interface is detected:

```bash
talosctl get links --nodes <NODE_IP>
```

2. Check network configuration:

```bash
talosctl get address --nodes <NODE_IP>
```

3. Test connectivity:

```bash
talosctl get routes --nodes <NODE_IP>
```

## Security Notes

- **Never commit secrets**: `talos-secrets.yaml` should be in `.gitignore`
- **API certificates**: Store securely, rotate regularly
- **IP KVM credentials**: Store in password manager, not in Git
- **Network security**: Configure firewall rules (Story 2.1)

## References

- [Talos Linux Documentation](https://www.talos.dev/)
- [Talos Linux GitHub](https://github.com/siderolabs/talos)
- [Story 1.1](../_bmad-output/implementation-artifacts/1-1-install-and-configure-talos-linux-base-system.md)
- [Architecture Document](../_bmad-output/planning-artifacts/architecture-homelab.md)

## Next Steps

After Talos Linux is installed and configured:

1. **Story 1.2**: Configure ZFS Storage Pool
2. **Story 1.3**: Deploy Kubernetes Cluster with Flux GitOps
3. **Story 1.4**: Configure Wake-on-LAN
