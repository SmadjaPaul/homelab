# Velero Backup & Restore Guide

## Overview

Velero backs up your Kubernetes cluster to Oracle Cloud Object Storage.

**Free Tier Limits:**
- 20 GB Object Storage total
- 10 GB allocated for Velero backups
- Auto-cleanup after 14 days

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Kubernetes     │────▶│     Velero      │────▶│  OCI Object     │
│  Resources      │     │                 │     │  Storage (S3)   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                      │
         │                      │
         ▼                      ▼
┌─────────────────┐     ┌─────────────────┐
│  PersistentVol  │────▶│    Restic       │
│  (data)         │     │  (file backup)  │
└─────────────────┘     └─────────────────┘
```

## Scheduled Backups

| Schedule | Frequency | Retention | Contents |
|----------|-----------|-----------|----------|
| `daily-backup` | 3 AM daily | 14 days | All namespaces, PVs |
| `weekly-full` | 4 AM Sunday | 30 days | Full cluster + PVs |

## Manual Backup

```bash
# Install Velero CLI
brew install velero

# Create a backup of everything
velero backup create full-backup --include-namespaces '*'

# Backup specific namespace
velero backup create grafana-backup --include-namespaces monitoring

# Backup with PV snapshots
velero backup create with-pvs --snapshot-volumes

# Check backup status
velero backup describe full-backup

# List all backups
velero backup get
```

## Restore Operations

### Full Cluster Restore

```bash
# List available backups
velero backup get

# Restore entire cluster
velero restore create --from-backup full-backup

# Check restore status
velero restore describe full-backup-restore

# Watch progress
velero restore logs full-backup-restore -f
```

### Restore Specific Namespace

```bash
# Restore only monitoring namespace
velero restore create --from-backup daily-backup \
  --include-namespaces monitoring

# Restore specific resources
velero restore create --from-backup daily-backup \
  --include-resources deployments,services,configmaps
```

### Restore to Different Namespace

```bash
# Restore monitoring to monitoring-restored
velero restore create --from-backup daily-backup \
  --include-namespaces monitoring \
  --namespace-mappings monitoring:monitoring-restored
```

## Disaster Recovery Scenarios

### Scenario 1: Namespace Deleted

```bash
# Check last backup
velero backup get

# Restore the namespace
velero restore create --from-backup daily-backup \
  --include-namespaces deleted-namespace

# Verify
kubectl get all -n deleted-namespace
```

### Scenario 2: Full Cluster Loss

```bash
# 1. Reinstall Kubernetes cluster (Talos)
talosctl apply-config ...

# 2. Install ArgoCD
kubectl apply -f kubernetes/argocd/

# 3. Install Velero (will sync from Git)
# Wait for ArgoCD to deploy Velero

# 4. Create credentials secret
kubectl create secret generic velero-credentials -n velero \
  --from-file=cloud=credentials.txt

# 5. Restore from backup
velero restore create --from-backup weekly-full

# 6. Wait for restore
velero restore logs weekly-full-restore -f
```

### Scenario 3: Accidental ConfigMap/Secret Deletion

```bash
# Restore specific resources
velero restore create --from-backup daily-backup \
  --include-resources configmaps,secrets \
  --include-namespaces affected-namespace
```

## Monitoring Backups

### Check Backup Status

```bash
# List all backups
velero backup get

# Detailed status
velero backup describe daily-backup-20260129030000

# Logs
velero backup logs daily-backup-20260129030000
```

### Prometheus Alerts

The following alerts are configured:

| Alert | Condition | Severity |
|-------|-----------|----------|
| `VeleroBackupFailed` | Backup failed | Critical |
| `VeleroBackupPartialFailure` | Partial failure | Warning |
| `VeleroNoRecentBackup` | No backup in 25h | Warning |
| `VeleroBackupStorageUnavailable` | S3 unreachable | Critical |

### Grafana Dashboard

Import dashboard ID: `16829` (Velero Statistics)

## Storage Management

### Check Usage

```bash
# OCI CLI - check bucket size
oci os object list \
  --namespace NAMESPACE \
  --bucket-name homelab-velero-backups \
  --query "sum(data[*].size)" \
  --output table
```

### Manual Cleanup

```bash
# Delete old backups
velero backup delete old-backup-name

# Delete all backups older than 7 days
velero backup get | grep -E "^daily" | head -7 | xargs -I {} velero backup delete {}
```

## Troubleshooting

### Backup Stuck in Progress

```bash
# Check Velero logs
kubectl logs -n velero deploy/velero -f

# Check node-agent logs (for PV backups)
kubectl logs -n velero ds/node-agent -f
```

### S3 Connection Issues

```bash
# Verify credentials
kubectl get secret velero-credentials -n velero -o yaml

# Test S3 connection
kubectl run aws-cli --rm -it --image=amazon/aws-cli -- \
  s3 ls s3://homelab-velero-backups \
  --endpoint-url https://NAMESPACE.compat.objectstorage.eu-paris-1.oraclecloud.com
```

### Restic Repository Lock

```bash
# Unlock stuck repository
velero restic repo unlock

# Or force unlock
kubectl exec -n velero deploy/velero -- \
  restic unlock --repo s3:https://...
```

## Best Practices

1. **Test restores regularly** - Don't wait for disaster
2. **Monitor backup alerts** - React to failures immediately
3. **Keep credentials secure** - Use SOPS for secrets
4. **Document recovery procedures** - This file!
5. **Verify storage quota** - Stay within 10GB limit

## Quick Reference

```bash
# Backup
velero backup create <name> [--include-namespaces <ns>]

# Restore
velero restore create --from-backup <backup-name>

# List
velero backup get
velero restore get

# Logs
velero backup logs <name>
velero restore logs <name>

# Delete
velero backup delete <name>
```
