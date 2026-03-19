# Spec: Backup — CNPG + PVCs (Velero)

## Contexte

Deux types de données à sauvegarder :
1. **Bases de données** : géré par CNPG via barman (WAL + base-backup vers S3 OCI)
2. **PVCs applicatives** : Nextcloud, Paperless, Audiobookshelf, etc. — **aucun backup actuel**

### État actuel

- **CNPG backup** : configuré dans le code (`kubernetes_registry.py`) mais **les clés Doppler étaient incorrectes** (`S3_BACKUP_ACCESS_KEY_ID` → corrigé en `OCI_S3_ACCESS_KEY`)
- **Bucket S3** : `velero-backups` existe dans OCI Object Storage (défini dans `apps.yaml`)
- **Credentials S3** : `OCI_S3_ACCESS_KEY` + `OCI_S3_SECRET_KEY` dans Doppler ✅
- **Endpoint S3 OCI** : `https://axnvxxurxefp.compat.objectstorage.eu-paris-1.oraclecloud.com`
- **Velero** : pas encore déployé

### Problème identifié — S3 CNPG backup

Le backup CNPG (`homelab-db`) référençait des clés Doppler inexistantes.
**Fix appliqué** (`kubernetes_registry.py`) : `S3_BACKUP_ACCESS_KEY_ID` → `OCI_S3_ACCESS_KEY`, `S3_BACKUP_SECRET_ACCESS_KEY` → `OCI_S3_SECRET_KEY`.

---

## Objectif

Backup complet en deux couches :
1. **CNPG** : WAL archiving + base-backup quotidien → S3 OCI (déjà configuré, fix clés appliqué)
2. **PVCs** : backup Velero des volumes persistants des apps `tier: critical` et `tier: standard`

---

## Scope

### In scope — Phase 1 : Valider CNPG backup (priorité)
- [x] Clés Doppler appliquées correctement dans la config CNPG (`OCI_S3_ACCESS_KEY`)
- [ ] Vérifier que le WAL archiving fonctionne (`kubectl get backup -n cnpg-system`)
- [ ] Valider : `kubectl get scheduledbackup -n cnpg-system`
- [ ] Configurer un `ScheduledBackup` CRD pour déclencher un backup quotidien à 2h00

### In scope — Phase 2 : Velero PVC backup
- [ ] Déployer Velero via Helm dans `k8s-storage`
- [ ] Configurer le backend S3 OCI (`velero-backups` bucket, credentials depuis Doppler)
- [ ] Créer des `Schedule` Velero :
  - Apps `tier: critical` : backup quotidien à 3h00, rétention 30j
  - Apps `tier: standard` : backup hebdomadaire (dimanche 4h00), rétention 14j
- [ ] Utiliser labels `homelab.dev/tier` pour cibler les apps
- [ ] Exclure PVCs `storage_class: local-path` (données éphémères non critiques)
- [ ] Exclure volumes Hetzner StorageBox (redondant côté Hetzner)

### Out of scope
- Restore automatisé
- Backup cross-region / cross-cloud
- Alerting sur échec backup (→ `alerting-auto.md`)

---

## Configuration S3 OCI

```yaml
# Endpoint OCI Object Storage (Paris)
endpoint: https://axnvxxurxefp.compat.objectstorage.eu-paris-1.oraclecloud.com
region: eu-paris-1
bucket: velero-backups

# Doppler keys (existants)
access_key: OCI_S3_ACCESS_KEY
secret_key: OCI_S3_SECRET_KEY
```

### Velero Helm values (référence)
```yaml
configuration:
  backupStorageLocation:
    - name: oci-s3
      provider: aws
      bucket: velero-backups
      config:
        region: eu-paris-1
        s3Url: https://axnvxxurxefp.compat.objectstorage.eu-paris-1.oraclecloud.com
        s3ForcePathStyle: "true"
  volumeSnapshotLocation: []  # Pas de snapshot CSI sur OKE Free Tier

credentials:
  useSecret: true
  secretContents:
    cloud: |
      [default]
      aws_access_key_id=<OCI_S3_ACCESS_KEY>
      aws_secret_access_key=<OCI_S3_SECRET_KEY>

# Utiliser Kopia (file-system backup) car pas de CSI snapshots
defaultVolumesToFsBackup: true
```

---

## CNPG ScheduledBackup CRD

À ajouter dans `k8s-storage/__main__.py` ou `kubernetes_registry.py` :

```python
k8s.apiextensions.CustomResource(
    "homelab-db-scheduled-backup",
    api_version="postgresql.cnpg.io/v1",
    kind="ScheduledBackup",
    metadata={
        "name": "homelab-db-daily",
        "namespace": "cnpg-system",
    },
    spec={
        "schedule": "0 2 * * *",  # 2h00 every day
        "backupOwnerReference": "self",
        "cluster": {"name": "homelab-db"},
        "method": "barmanObjectStore",
    },
    opts=opts,
)
```

---

## Contraintes
- Secrets via Doppler uniquement (`OCI_S3_ACCESS_KEY`, `OCI_S3_SECRET_KEY`)
- Tout passe par Pulumi (pas de kubectl apply direct)
- Budget OCI : backup S3 est dans `velero-backups` bucket (déjà provisionné, 50GB min)
- Velero Kopia = file-system backup (pas de CSI snapshot sur OKE Free Tier ARM)

---

## Critères d'acceptance

### Phase 1 — CNPG
- [ ] `kubectl get backup -n cnpg-system` montre un backup récent (< 24h)
- [ ] `kubectl get scheduledbackup -n cnpg-system` montre `homelab-db-daily` scheduled
- [ ] Le bucket S3 `velero-backups` contient des fichiers WAL

### Phase 2 — Velero
- [ ] `uv run pulumi preview --stack oci` passe sans erreur
- [ ] `velero get schedules` montre les schedules configurés
- [ ] `velero get backups` montre un backup réussi dans les 24h
- [ ] Les PVCs `tier: critical` (authentik, vaultwarden) sont incluses
- [ ] Les PVCs `storage_class: local-path` ne sont PAS sauvegardées
- [ ] Test restore : `velero restore create --from-backup <name>` fonctionne

---

## Fichiers concernés

| Fichier | Modification |
|---|---|
| `kubernetes-pulumi/shared/apps/common/kubernetes_registry.py` | ✅ Fix clés Doppler CNPG backup (`OCI_S3_ACCESS_KEY`) |
| `kubernetes-pulumi/apps.yaml` | Ajouter Velero comme app dans `k8s-storage` |
| `kubernetes-pulumi/k8s-storage/__main__.py` | Déployer Velero + ScheduledBackup CNPG |

## Notes / Références
- Velero Helm chart : https://github.com/vmware-tanzu/helm-charts
- OCI Object Storage S3 compat : https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/s3compatibleapi.htm
- CNPG ScheduledBackup : https://cloudnative-pg.io/documentation/current/scheduled_backup/
- Velero Kopia (fs-backup) : https://velero.io/docs/latest/file-system-backup/
