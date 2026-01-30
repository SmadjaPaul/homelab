---
sidebar_position: 1
---

# Proxmox VE

## Spécifications

| Composant | Détails |
|-----------|---------|
| Machine | AOOSTAR WTR MAX |
| CPU | AMD Ryzen 7 8845HS |
| RAM | 64 GB DDR5 |
| SSD | 1 TB NVMe (système) |
| HDD | 2x 20 TB (stockage ZFS) |
| GPU | NVIDIA (passthrough gaming) |
| IP | 192.168.68.51 |

## Accès

| Méthode | URL/Commande |
|---------|--------------|
| Web UI | https://proxmox.smadja.dev (via Twingate) |
| SSH | `ssh root@192.168.68.51` |
| API | Port 8006 |

## Configuration

### Post-installation

Exécuter le script après installation :

```bash
bash <(curl -s https://raw.githubusercontent.com/SmadjaPaul/homelab/main/scripts/proxmox/post-install.sh)
```

Ce script :
- Désactive le repo enterprise
- Active le repo no-subscription
- Configure IOMMU pour GPU passthrough
- Installe les outils utiles

### ZFS Storage

```bash
# Créer le pool ZFS
./scripts/proxmox/setup-zfs.sh
```

Configuration recommandée :
- **Pool** : tank (mirror ou single selon backup strategy)
- **Compression** : lz4
- **Datasets** : vm-disks, containers, backups, iso

### GPU Passthrough

1. IOMMU activé dans BIOS
2. Modules VFIO chargés
3. GPU isolé du host

```bash
# Vérifier IOMMU
dmesg | grep -e DMAR -e IOMMU

# Vérifier GPU
lspci | grep -i nvidia
```

## VMs

### Talos Linux (Kubernetes)

| VM | vCPU | RAM | Disk | Rôle |
|----|------|-----|------|------|
| talos-dev | 2 | 4 GB | 50 GB | Cluster DEV |
| talos-prod-cp | 2 | 4 GB | 50 GB | Control Plane |
| talos-prod-worker | 6 | 12 GB | 200 GB | Worker |

### Gaming VM (Future)

| VM | vCPU | RAM | Disk | GPU |
|----|------|-----|------|-----|
| windows-gaming | 8 | 32 GB | 1 TB | NVIDIA |

## Backup

### ZFS Snapshots

```bash
# Snapshot manuel
zfs snapshot tank/vm-disks@backup-$(date +%Y%m%d)

# Lister les snapshots
zfs list -t snapshot
```

### Proxmox Backup

Configuration via UI ou CLI :

```bash
# Backup VM
vzdump <vmid> --storage local --mode snapshot
```

## Monitoring

Prometheus scrape les métriques Proxmox via `pve-exporter`.

Dashboards Grafana disponibles :
- Proxmox Overview
- VM Resources
- Storage Usage
