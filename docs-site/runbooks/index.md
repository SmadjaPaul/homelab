---
sidebar_position: 1
slug: /runbooks
---

# Runbooks

Procédures opérationnelles pour la gestion du homelab.

## Organisation

### Incidents

Procédures de réponse aux incidents :

- [Service Down](/runbooks/incidents/service-down)
- [Disk Full](/runbooks/incidents/disk-full)
- [High CPU](/runbooks/incidents/high-cpu)
- [Certificate Expired](/runbooks/incidents/certificate-expired)

### Maintenance

Procédures de maintenance régulière :

- [Backup & Restore](/runbooks/maintenance/backup-restore)
- [Upgrade Cluster](/runbooks/maintenance/upgrade-cluster)
- [Rotate Secrets](/runbooks/maintenance/rotate-secrets)

## Format des runbooks

Chaque runbook suit ce format :

1. **Symptômes** : Comment détecter le problème
2. **Impact** : Quels services sont affectés
3. **Diagnostic** : Commandes pour investiguer
4. **Résolution** : Étapes pour corriger
5. **Prévention** : Comment éviter à l'avenir

## Alertes associées

| Alerte | Runbook |
|--------|---------|
| ServiceDown | [Service Down](/runbooks/incidents/service-down) |
| DiskAlmostFull | [Disk Full](/runbooks/incidents/disk-full) |
| HighCpuUsage | [High CPU](/runbooks/incidents/high-cpu) |
| CertificateExpiring | [Certificate Expired](/runbooks/incidents/certificate-expired) |
