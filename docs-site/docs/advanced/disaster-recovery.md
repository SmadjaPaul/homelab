---
sidebar_position: 4
---

# Disaster Recovery

## Plan de reprise

### Niveaux de criticité

| Niveau | Temps de reprise | Services |
|--------|------------------|----------|
| P0 | < 1h | Auth, Status |
| P1 | < 4h | Homepage, Monitoring |
| P2 | < 24h | Apps utilisateur |
| P3 | < 72h | Services optionnels |

## Scénarios

### 1. Pod/Deployment crashé

**Symptômes**: Service inaccessible, alerts Prometheus

**Actions**:
```bash
# Vérifier le status
kubectl get pods -n <namespace>

# Logs
kubectl logs -f deploy/<name> -n <namespace>

# Restart
kubectl rollout restart deploy/<name> -n <namespace>
```

### 2. Node Kubernetes down

**Symptômes**: Multiple pods down, node NotReady

**Actions**:
```bash
# Vérifier les nodes
kubectl get nodes

# Détails du node
kubectl describe node <node-name>

# Si VM Proxmox:
# 1. Vérifier dans l'UI Proxmox
# 2. Restart la VM si nécessaire
qm start <vmid>
```

### 3. Cluster entier perdu

**Symptômes**: Aucun accès kubectl, ArgoCD down

**Actions**:
```bash
# 1. Recréer le cluster
talosctl apply-config -n <node-ip> -f talos-config.yaml
talosctl bootstrap -n <node-ip>

# 2. Récupérer kubeconfig
talosctl kubeconfig -n <node-ip>

# 3. Installer ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 4. Configurer le repo
argocd repo add git@github.com:SmadjaPaul/homelab.git --ssh-private-key-path ~/.ssh/argocd

# 5. Sync root app
kubectl apply -f kubernetes/argocd/app-of-apps.yaml

# 6. Restaurer depuis Velero
velero restore create --from-backup <latest-backup>
```

### 4. Proxmox host down

**Symptômes**: Toutes les VMs locales down

**Actions**:
```bash
# 1. Accéder physiquement au serveur
# 2. Vérifier le boot / erreurs
# 3. Si disque corrompu:
#    - Boot sur USB Proxmox
#    - Importer le ZFS pool

# Import ZFS
zpool import -f tank

# 4. Restaurer VMs depuis snapshots
zfs list -t snapshot
zfs rollback tank/vm-disks@<snapshot>
```

### 5. Oracle Cloud indisponible

**Symptômes**: Services cloud down, VMs OCI inaccessibles

**Actions**:
- Vérifier [OCI Status](https://ocistatus.oraclecloud.com/)
- Attendre la résolution Oracle
- Rediriger le trafic vers local si possible (mise à jour DNS)

### 6. Cloudflare down

**Symptômes**: Tous les services *.smadja.dev inaccessibles

**Actions**:
- Vérifier [Cloudflare Status](https://www.cloudflarestatus.com/)
- Accéder via Twingate (bypass Cloudflare)
- Accès direct aux IPs Oracle si nécessaire

## Procédures de restauration

### Restaurer un namespace

```bash
velero restore create ns-restore \
  --from-backup daily-backup \
  --include-namespaces <namespace>

# Vérifier
velero restore describe ns-restore
kubectl get all -n <namespace>
```

### Restaurer des secrets

```bash
# Depuis SOPS
sops -d secrets/<secret>.enc.yaml | kubectl apply -f -

# Depuis Velero
velero restore create --from-backup <backup> \
  --include-resources secrets \
  --include-namespaces <namespace>
```

### Restaurer la config Terraform

```bash
# Le state est sur TFstate.dev
cd terraform/oracle-cloud
terraform init
terraform plan
# Vérifier que l'état correspond
```

## Contacts & Escalation

| Niveau | Contact | Méthode |
|--------|---------|---------|
| 1 | Paul | Discord / SMS |
| 2 | (backup) | Email |

## Post-mortem

Après chaque incident majeur :

1. Documenter la timeline
2. Identifier la cause racine
3. Définir les actions correctives
4. Mettre à jour les runbooks
5. Améliorer le monitoring si nécessaire
