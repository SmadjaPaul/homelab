# Architecture GitOps Complète - Déploiement 100% Automatisé

## Vue d'Ensemble

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         GITHUB ACTIONS (CI/CD)                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Workflow: full-bootstrap.yaml                                              │
│  ├── Job 1: Infrastructure (Terraform)                                      │
│  │   ├── Cloudflare (DNS, Tunnel)                                          │
│  │   └── OCI (VMs Ubuntu temporaires)                                      │
│  │                                                                          │
│  ├── Job 2: Omni Bootstrap (Automatique)                                   │
│  │   ├── Créer cluster Omni                                                │
│  │   ├── Générer image Talos                                               │
│  │   ├── Upload vers OCI                                                   │
│  │   ├── Créer image custom                                                │
│  │   └── Re-déployer VMs avec Talos                                        │
│  │                                                                          │
│  └── Job 3: Kubernetes Apps (Flux CD)                                      │
│      ├── Installer Flux                                                    │
│      └── Déployer toutes les apps                                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      │ (Automatique)
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         INFRASTRUCTURE (OCI)                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  VM-Hub (oci-hub)                                                           │
│  ├── Omni (Control Plane)                                                   │
│  ├── Tailscale (Subnet Router)                                              │
│  └── Comet (Streaming)                                                      │
│                                                                             │
│  Cluster K8s (Talos Linux)                                                  │
│  ├── Control Plane (talos-cp-1)                                             │
│  └── Workers (talos-worker-1, talos-worker-2)                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      │ (GitOps)
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         APPLICATIONS (Flux CD)                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Infrastructure                                                             │
│  ├── Cloudflared (Tunnel)                                                   │
│  ├── External DNS                                                           │
│  ├── Cert-manager                                                           │
│  └── Traefik                                                                │
│                                                                             │
│  Apps                                                                        │
│  ├── Authentik (IdP)                                                        │
│  ├── Nextcloud (Cloud)                                                      │
│  └── ...                                                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Niveaux d'Automatisation

### ✅ 100% Automatisé

| Composant | Outil | Automatisation |
|-----------|-------|----------------|
| **Cloudflare** | Terraform | 100% - DNS, Tunnel, Access |
| **OCI VMs** | Terraform | 100% - Création, réseau, sécurité |
| **Image Talos** | Omni API + OCI CLI | 100% - Génération, upload, import |
| **Flux CD** | kubectl | 100% - Installation, configuration |
| **Apps** | Flux CD | 100% - Déploiement continu depuis Git |
| **Secrets** | External Secrets | 100% - Sync Doppler → Kubernetes |

### ⚠️ Semi-Automatisé (1ère fois uniquement)

| Composant | Pourquoi ? | Solution |
|-----------|-----------|----------|
| **Création compte Omni** | Nécessite une interaction web pour la première config | UI Omni obligatoire (1 fois) |
| **Génération clé API Omni** | Token de sécurité à créer manuellement | Omni UI → Settings → Keys (1 fois) |
| **Bootstrap initial** | Nécessite kubeconfig du cluster | Script automatisé après 1ère config |

## Workflows GitHub Actions

### 1. `full-bootstrap.yaml` - Déploiement Complet

```bash
# Déployer TOUT d'un coup
GitHub Actions → Full Bootstrap → Run workflow → step: all
```

**Jobs:**

#### Job 1: Infrastructure
- Durée: ~5 minutes
- Actions:
  1. Terraform init/apply Cloudflare
  2. Terraform init/apply OCI (VMs Ubuntu)
  3. Output des IPs

#### Job 2: Omni Bootstrap
- Durée: ~20 minutes (l'import d'image OCI prend du temps)
- Actions:
  1. Installer talosctl, omnictl, oci-cli
  2. Créer cluster dans Omni via API
  3. Générer image Talos pour Oracle Cloud
  4. Upload vers OCI Object Storage
  5. Créer image custom (attente 10-15 min)
  6. Mettre à jour terraform.tfvars
  7. Re-déployer VMs avec image Talos

#### Job 3: Kubernetes Apps
- Durée: ~10 minutes
- Actions:
  1. Installer Flux CD
  2. Créer secret Doppler
  3. Déployer toutes les apps
  4. Vérifications

### 2. `terraform.yaml` - Contrôle Granulaire

```bash
# Déployer uniquement Cloudflare
GitHub Actions → Terraform → workspace: cloudflare → apply

# Déployer uniquement OCI
GitHub Actions → Terraform → workspace: oracle-cloud → apply
```

### 3. `lint.yaml` - Validation

À chaque push/PR:
- Validation YAML
- Validation Terraform
- Check formatting

### 4. `security.yaml` - Sécurité

- Scan Trivy (vulnérabilités)
- Scan Checkov (meilleures pratiques)

### 5. `flux-diff.yaml` - GitOps

Affiche le diff entre Git et cluster.

## Processus de Déploiement Complet

### Prérequis (1 fois)

1. **Créer compte Omni**
   ```
   Aller sur https://omni.siderolabs.io
   Créer compte
   Noter l'endpoint: https://xxx.omni.siderolabs.io:50001
   ```

2. **Générer clé API Omni**
   ```
   Omni UI → Settings → Keys → Generate
   Noter la clé: omni-key-xxx
   ```

3. **Configurer secrets GitHub**
   ```yaml
   OMNI_ENDPOINT: https://xxx.omni.siderolabs.io:50001
   OMNI_KEY: omni-key-xxx
   DOPPLER_TOKEN: dp.st.xxx
   OCI_COMPARTMENT_ID: ocid1.compartment...
   CLOUDFLARE_API_TOKEN: xxx
   # ... (voir liste complète dans README)
   ```

### Déploiement (1 clic)

```bash
GitHub Actions → Full Bootstrap → Run workflow
```

**Durée totale: ~40 minutes**

1. Infrastructure: 5 min
2. Omni Bootstrap: 20 min (import image OCI)
3. Kubernetes Apps: 10 min
4. Vérifications: 5 min

## Architecture Technique Détaillée

### Génération Automatique de l'Image Talos

Le script `scripts/omni-bootstrap.sh` automatise:

```bash
1. omnictl cluster create oci-hub
   → Crée le cluster dans Omni

2. curl $OMNI_ENDPOINT/api/v1/clusters/oci-hub/image?platform=oracle
   → Télécharge l'image préconfigurée

3. qemu-img convert raw → qcow2
   → Conversion format OCI

4. tar czf image.oci
   → Création bundle OCI

5. oci os object put
   → Upload vers bucket

6. oci compute image create
   → Création image custom

7. Wait for AVAILABLE
   → Attente disponibilité (10-15 min)

8. Update terraform.tfvars
   → Mise à jour automatique
```

### Gestion des Dépendances

```yaml
# Workflows utilisent 'needs' pour l'ordre:
job-2:
  needs: job-1  # Job-2 attend que job-1 réussisse

job-3:
  needs: job-2  # Job-3 attend que job-2 réussisse
```

### Gestion des Secrets

**Secrets GitHub (Settings → Secrets):**

| Secret | Utilisation | Où ? |
|--------|-------------|------|
| `OMNI_ENDPOINT` | URL Omni | Job 2 |
| `OMNI_KEY` | Clé API Omni | Job 2 |
| `DOPPLER_TOKEN` | Token infrastructure | Job 3 |
| `KUBECONFIG_OMNI` | Kubeconfig encodé | Job 3 |
| `OCI_*` | Credentials OCI | Jobs 1, 2 |
| `CLOUDFLARE_*` | Token Cloudflare | Job 1 |

### Environments (Protection)

**GitHub Environments** avec approbation manuelle:

- `cloudflare`: Pour Terraform Cloudflare
- `production`: Pour Terraform OCI (VMs)
- `omni`: Pour Omni bootstrap
- `kubernetes`: Pour déploiement apps

## Avantages de cette Architecture

### ✅ Avantages

1. **1 clic = Infrastructure complète**
   - Plus besoin de faire les étapes manuellement
   - Reproductible à l'identique

2. **Idempotent**
   - Peut relancer sans casser
   - Terraform gère l'état

3. **Audit trail**
   - Tout est logué dans GitHub Actions
   - Historique des déploiements

4. **Rollback possible**
   - Terraform destroy
   - Git revert

5. **Multi-environnement**
   - Facilement adaptable pour dev/staging/prod

### ⚠️ Contraintes

1. **Première config Omni manuelle**
   - Incontournable (création compte + clé API)
   - Mais fait 1 fois seulement

2. **Temps d'import OCI**
   - 10-15 minutes pour l'image
   - Limitation OCI, pas optimisable

3. **Coûts potentiels**
   - Bucket OCI pour l'image temporaire
   - ~€0.10 par déploiement

## Scénarios d'Usage

### Scénario 1: Premier Déploiement

```bash
# 1. Configurer secrets GitHub (1 fois)

# 2. Lancer le workflow
GitHub Actions → Full Bootstrap → all

# 3. Attendre 40 minutes

# 4. Résultat: Infrastructure complète prête
```

### Scénario 2: Re-créer le Cluster

```bash
# Détruire tout
GitHub Actions → Terraform → destroy

# Re-créer
GitHub Actions → Full Bootstrap → all
```

### Scénario 3: Ajouter une Application

```bash
# 1. Modifier kubernetes/apps/productivity/wiki/
# 2. git push
# 3. Flux CD déploie automatiquement (30s)
```

### Scénario 4: Mise à Jour

```bash
# Mise à jour Terraform
GitHub Actions → Terraform → apply

# Mise à jour apps
Git push sur kubernetes/
```

## Monitoring du Déploiement

**Suivre en temps réel:**

1. **GitHub Actions UI**
   - Voir les logs de chaque job
   - Temps d'exécution
   - Éventuelles erreurs

2. **Omni UI**
   - Voir les nœuds rejoindre le cluster
   - État du cluster

3. **OCI Console**
   - Voir les VMs créées
   - Images custom disponibles

4. **Cloudflare Dashboard**
   - Voir les DNS records
   - État du tunnel

## Commandes de Dépannage

```bash
# Voir les logs GitHub Actions
gitHub UI → Actions → <workflow> → <job>

# Vérifier Omni
omnictl cluster get oci-hub
omnictl cluster machines -c oci-hub

# Vérifier OCI
oci compute instance list --compartment-id $OCI_COMPARTMENT_ID

# Vérifier Kubernetes
kubectl get nodes
kubectl get pods -A

# Vérifier Flux
flux get all
flux logs
```

## Roadmap d'Amélioration

- [ ] **Health checks** automatisés post-déploiement
- [ ] **Notifications** Slack/Discord
- [ ] **Tests** de validation (smoke tests)
- [ ] **Backup** automatique de l'état Terraform
- [ ] **Multi-région** (réplication OCI)

## Conclusion

**95% automatisé** - Seule la création initiale du compte Omni reste manuelle (sécurité + contrainte technique).

**Avec ce workflow, déployer l'infrastructure complète prend 40 minutes et 1 clic !** 🚀
