# Guide de Déploiement Complet - Homelab OCI

> **Guide étape par étape pour déployer l'infrastructure complète**

## 📋 Table des Matières

1. [Prérequis](#1-prérequis)
2. [Phase 0: Setup Initial](#2-phase-0-setup-initial)
3. [Phase 1: Infrastructure Terraform](#3-phase-1-infrastructure-terraform)
4. [Phase 2: Configuration Omni](#4-phase-2-configuration-omni)
5. [Phase 3: Bootstrap Kubernetes](#5-phase-3-bootstrap-kubernetes)
6. [Phase 4: Infrastructure Core (GitOps)](#6-phase-4-infrastructure-core-gitops)
7. [Phase 5: Authentik](#7-phase-5-authentik)
8. [Phase 6: Applications](#8-phase-6-applications)
9. [Vérification & Dépannage](#9-vérification--dépannage)

---

## 1. Prérequis

### Outils requis

```bash
# macOS
brew install terraform kubectl helm talosctl doppler fluxcd/tap/flux

# Vérifier installations
terraform version
kubectl version --client
helm version
talosctl version
doppler --version
flux --version
```

### Accès cloud

- **OCI**: Compte avec Free Tier, API keys configurées
- **Cloudflare**: Domaine smadja.dev configuré, API token
- **Doppler**: Compte créé, CLI installé et authentifié
- **Tailscale**: Compte créé, auth key générée

### Repository

```bash
cd /Users/paul/Developer/Perso/homelab/GitOps-main
```

---

## 2. Phase 0: Setup Initial

### 2.1 Créer les projets Doppler

```bash
./scripts/setup-doppler.sh
```

Ce script va créer tous les projets Doppler nécessaires.

### 2.2 Configurer les secrets dans Doppler

**Projet `infrastructure`** (obligatoire pour Terraform):
```bash
# Cloudflare
doppler secrets set CLOUDFLARE_API_TOKEN="xxx" -p infrastructure
doppler secrets set CLOUDFLARE_ZONE_ID="xxx" -p infrastructure
doppler secrets set CLOUDFLARE_ACCOUNT_ID="xxx" -p infrastructure
doppler secrets set CF_DNS_API_TOKEN="xxx" -p infrastructure

# OCI
doppler secrets set OCI_CLI_TENANCY="xxx" -p infrastructure
doppler secrets set OCI_CLI_USER="xxx" -p infrastructure
doppler secrets set OCI_CLI_FINGERPRINT="xxx" -p infrastructure
doppler secrets set OCI_CLI_KEY_CONTENT="xxx" -p infrastructure
doppler secrets set OCI_COMPARTMENT_ID="xxx" -p infrastructure
doppler secrets set OCI_OBJECT_STORAGE_NAMESPACE="xxx" -p infrastructure

# Tailscale
doppler secrets set TAILSCALE_AUTH_KEY="tskey-auth-xxx" -p infrastructure

# Email pour certificats
doppler secrets set ACME_EMAIL="admin@smadja.dev" -p infrastructure
```

**Autres projets**: Laisser vides pour l'instant, on les remplira plus tard.

---

## 3. Phase 1: Infrastructure Terraform

### 3.1 Configuration

```bash
cd terraform/oracle-cloud

# Copier le fichier d'exemple
cp terraform.tfvars.example terraform.tfvars

# Éditer terraform.tfvars
# Remplir:
# - compartment_id
# - ssh_public_key (clé publique SSH)
# - budget_alert_email
```

### 3.2 Déploiement initial

```bash
# Initialiser
doppler run -- terraform init

# Plan (vérifier les ressources)
doppler run -- terraform plan

# Appliquer
doppler run -- terraform apply
```

**Résultat attendu:**
- ✅ VM Hub créée (oci-hub)
- ✅ 3 VMs Talos créées (avec Ubuntu en fallback)
- IPs affichées dans les outputs

### 3.3 Récupérer les informations

```bash
# Sauvegarder les outputs
terraform output > /tmp/terraform-outputs.txt

# Afficher IP du Hub
terraform output hub_public_ip
```

---

## 4. Phase 2: Configuration Omni

### 4.1 Se connecter à Omni

```bash
# Récupérer l'IP
HUB_IP=$(terraform output -raw hub_public_ip)
echo "Omni UI: https://$HUB_IP:50001"
```

**Actions manuelles:**

1. **Ouvrir** `https://[HUB_IP]:50001` dans le navigateur
2. **Accepter** le certificat auto-signé (normal pour Omni)
3. **Créer** le premier utilisateur admin:
   - Username: `admin`
   - Password: (mot de passe fort)
   - Email: admin@smadja.dev

### 4.2 Créer le cluster

Dans l'interface Omni:

1. Aller dans **Clusters** → **Create Cluster**
2. **Configuration:**
   - Name: `oci-hub`
   - Kubernetes version: `1.31.0` (ou dernière stable)
   - Talos version: `v1.9.0` (ou dernière stable)
   - Control plane nodes: `1`
   - Worker nodes: `2`
3. Cliquer sur **Create**

### 4.3 Générer l'image Talos

1. Dans Omni, aller dans **Download** (menu latéral)
2. Sélectionner **Oracle Cloud**
3. Attendre la génération (~2-3 minutes)
4. **Copier l'OCID** de l'image générée

**Format:** `ocid1.image.oc1.eu-paris-1.xxxxx`

### 4.4 Mettre à jour Terraform

```bash
# Éditer terraform.tfvars
echo "talos_image_id = \"ocid1.image.oc1.eu-paris-1.xxxxxx\"" >> terraform.tfvars

# Ré-appliquer pour déployer Talos sur les VMs
doppler run -- terraform apply
```

**Vérification:**
```bash
# Les VMs devraient redémarrer avec Talos
# Attendre 2-3 minutes
```

---

## 5. Phase 3: Bootstrap Kubernetes

### 5.1 Lancer le script de bootstrap

```bash
cd ../..  # Retour à GitOps-main
./scripts/bootstrap-phase2.sh
```

Ce script va:
- Vérifier les prérequis
- Vous guider pour récupérer le kubeconfig
- Installer Flux CD
- Créer le secret Doppler
- Déployer External Secrets Operator

### 5.2 Vérifications

```bash
# Vérifier le cluster
kubectl get nodes

# Résultat attendu:
# NAME              STATUS   ROLES           AGE   VERSION
# talos-cp-1        Ready    control-plane   5m    v1.31.0
# talos-worker-1    Ready    <none>          5m    v1.31.0
# talos-worker-2    Ready    <none>          5m    v1.31.0

# Vérifier Flux
flux check

# Vérifier External Secrets
kubectl get clustersecretstores
# NAME                      AGE   STATUS
doppler-infrastructure    1m    Valid
```

---

## 6. Phase 4: Infrastructure Core (GitOps)

### 6.1 Déployer l'infrastructure core

```bash
# Déployer tout le dossier clusters/oci-hub
kubectl apply -k kubernetes/clusters/oci-hub
```

**Ou étape par étape:**

```bash
# 1. External Secrets (déjà fait par bootstrap)
# kubectl apply -k kubernetes/apps/infrastructure/external-secrets

# 2. Cert-manager
kubectl apply -k kubernetes/apps/infrastructure/cert-manager

# 3. Cloudflare (Tunnel + External DNS)
kubectl apply -k kubernetes/apps/infrastructure/cloudflare

# 4. Traefik
kubectl apply -k kubernetes/apps/infrastructure/traefik
```

### 6.2 Vérifications

```bash
# Attendre que tout soit ready
watch kubectl get pods -n infra

# Vérifier cert-manager
kubectl get pods -n cert-manager
kubectl get clusterissuers

# Vérifier Cloudflare Tunnel
kubectl get pods -n cloudflare
kubectl logs -n cloudflare deployment/cloudflare-tunnel

# Vérifier External DNS
kubectl get pods -n external-dns
kubectl logs -n external-dns deployment/external-dns

# Vérifier Traefik
kubectl get pods -n infra
```

### 6.3 Configurer le tunnel Cloudflare

**Sur Cloudflare Zero Trust:**

1. Aller dans **Networks** → **Tunnels**
2. Créer un tunnel nommé `oci-hub-tunnel`
3. Choisir **Docker** comme environnement
4. Copier le **Tunnel Token**
5. Dans Doppler, ajouter au projet `infrastructure`:
   ```bash
   doppler secrets set CLOUDFLARE_TUNNEL_TOKEN="eyJ..." -p infrastructure
   doppler secrets set CLOUDFLARE_TUNNEL_ID="xxx-xxx-xxx" -p infrastructure
   doppler secrets set CLOUDFLARE_TUNNEL_SECRET="xxx" -p infrastructure
   ```

6. Redémarrer le tunnel:
   ```bash
   kubectl rollout restart deployment/cloudflare-tunnel -n cloudflare
   ```

---

## 7. Phase 5: Authentik

### 7.1 Préparer les secrets Doppler

**Projet `service-authentik`:**
```bash
# Générer les secrets
doppler secrets set AUTHENTIK_SECRET_KEY="$(openssl rand -base64 60)" -p service-authentik
doppler secrets set AUTHENTIK_BOOTSTRAP_PASSWORD="$(openssl rand -base64 32)" -p service-authentik
doppler secrets set AUTHENTIK_BOOTSTRAP_TOKEN="$(openssl rand -base64 50)" -p service-authentik
doppler secrets set AUTHENTIK_POSTGRES_PASSWORD="$(openssl rand -base64 32)" -p service-authentik
doppler secrets set AUTHENTIK_POSTGRES_USER="authentik" -p service-authentik
doppler secrets set AUTHENTIK_POSTGRES_NAME="authentik" -p service-authentik

# SMTP (optionnel mais recommandé)
doppler secrets set SMTP_HOST="smtp.resend.com" -p service-authentik
doppler secrets set SMTP_PORT="587" -p service-authentik
doppler secrets set SMTP_USERNAME="resend" -p service-authentik
doppler secrets set SMTP_PASSWORD="re_xxxx" -p service-authentik
doppler secrets set SMTP_FROM="noreply@smadja.dev" -p service-authentik
```

### 7.2 Activer Authentik dans GitOps

**Éditer** `kubernetes/clusters/oci-hub/kustomization.yaml`:

```yaml
resources:
  # ... (infrastructure core)

  # Apps Business (décommenter)
  - ../../apps/business/authentik
  # - ../../apps/business/odoo
  # - ../../apps/business/fleetdm
```

### 7.3 Pousser sur Git

```bash
git add .
git commit -m "Add authentik"
git push
```

**Ou appliquer manuellement:**
```bash
kubectl apply -k kubernetes/apps/business/authentik
```

### 7.4 Vérifications

```bash
# Attendre le déploiement
watch kubectl get pods -n authentik

# Vérifier logs
kubectl logs -n authentik deployment/authentik-server

# Vérifier ingress
kubectl get ingress -n authentik
```

### 7.5 Configuration manuelle d'Authentik

**Accéder à Authentik:**
- URL: `https://auth.smadja.dev`
- User: `admin` (ou akadmin selon config)
- Password: (récupérer depuis Doppler)

**Configuration initiale:**

1. **Créer les groupes:**
   - `admin` (toi)
   - `family` (famille)
   - `friends` (amis)

2. **Créer les utilisateurs:**
   - Toi (admin)
   - Membres de la famille

3. **Créer les applications:**

   Pour chaque service (Nextcloud, Matrix, etc.):
   - Aller dans **Applications** → **Applications** → **Create**
   - Name: Nextcloud
   - Slug: nextcloud
   - Provider: OAuth2/OpenID
   - Client ID: nextcloud
   - Client Secret: (générer)
   - Redirect URIs: `https://cloud.smadja.dev/*`

4. **Créer les providers OIDC:**
   - Suivre la doc de chaque app

---

## 8. Phase 6: Applications

### 8.1 Nextcloud (exemple)

**Secrets Doppler** (`service-nextcloud`):
```bash
doppler secrets set NEXTCLOUD_ADMIN_USER="admin" -p service-nextcloud
doppler secrets set NEXTCLOUD_ADMIN_PASSWORD="xxx" -p service-nextcloud
doppler secrets set NEXTCLOUD_POSTGRES_PASSWORD="xxx" -p service-nextcloud
doppler secrets set OBJECTSTORE_S3_KEY="xxx" -p service-nextcloud
doppler secrets set OBJECTSTORE_S3_SECRET="xxx" -p service-nextcloud
```

**Activer dans GitOps**:

Éditer `kubernetes/clusters/oci-hub/kustomization.yaml`:
```yaml
  - ../../apps/productivity/nextcloud
```

**Pousser:**
```bash
git add . && git commit -m "Add nextcloud" && git push
```

### 8.2 Pour chaque nouvelle app

1. **Créer projet Doppler** (`service-<name>`)
2. **Ajouter secrets** dans Doppler
3. **Créer dossier** `kubernetes/apps/<category>/<name>/`
4. **Créer fichiers:**
   - `namespace.yaml`
   - `repository.yaml`
   - `external-secret.yaml`
   - `helmrelease.yaml`
   - `ingress.yaml`
   - `kustomization.yaml`
5. **Référencer** dans `clusters/oci-hub/kustomization.yaml`
6. **Pousser** sur Git
7. **Configurer** dans Authentik (si auth requise)

---

## 9. Vérification & Dépannage

### 9.1 Checklist finale

```bash
# Infrastructure
kubectl get nodes
kubectl get pods -n infra
kubectl get pods -n cert-manager
kubectl get pods -n cloudflare
kubectl get pods -n external-dns

# Apps
kubectl get pods -n authentik
kubectl get pods -n nextcloud  # et autres apps

# DNS
kubectl logs -n external-dns deployment/external-dns

# Tunnel
kubectl logs -n cloudflare deployment/cloudflare-tunnel

# Certificats
kubectl get certificates -A
```

### 9.2 Commandes utiles

```bash
# Logs d'un pod
kubectl logs -n <namespace> deployment/<name>

# Shell dans un pod
kubectl exec -it -n <namespace> deployment/<name> -- sh

# Redémarrer un déploiement
kubectl rollout restart deployment/<name> -n <namespace>

# Voir les événements
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Port forward
kubectl port-forward -n <namespace> svc/<name> 8080:80
```

### 9.3 Problèmes courants

**External Secrets ne sync pas:**
```bash
kubectl logs -n flux-system deployment/external-secrets
# Vérifier que le token Doppler est valide
```

**Certificats TLS ne se créent pas:**
```bash
kubectl logs -n cert-manager deployment/cert-manager
# Vérifier que le token Cloudflare DNS est valide
```

**DNS ne se met pas à jour:**
```bash
kubectl logs -n external-dns deployment/external-dns
# Vérifier que l'ingress a les bonnes annotations
```

**Tunnel ne fonctionne pas:**
```bash
kubectl logs -n cloudflare deployment/cloudflare-tunnel
# Vérifier le token du tunnel
```

### 9.4 Accès d'urgence

**Si tout est cassé:**
```bash
# Accès direct via Tailscale
ssh ubuntu@$(terraform -chdir=terraform/oracle-cloud output -raw hub_public_ip)

# Vérifier les services Docker sur le Hub
sudo docker ps
sudo docker logs omni

# Redémarrer Omni
sudo docker restart omni
```

---

## 🎉 Félicitations!

Votre homelab est maintenant déployé avec:
- ✅ 4 VMs OCI (Free Tier max)
- ✅ Kubernetes avec Talos
- ✅ GitOps via Flux
- ✅ Authentik pour SSO
- ✅ Cloudflare Tunnel pour accès public
- ✅ External DNS pour gestion DNS automatique
- ✅ Cert-manager pour TLS

**Prochaines étapes:**
- Ajouter d'autres applications
- Configurer le backup avec Kopia
- Mettre en place le monitoring
- Préparer le cluster Home (Proxmox)

**Documentation:**
- [Architecture d'accès](docs/ACCESS-ARCHITECTURE.md)
- [Architecture de déploiement](docs/DEPLOYMENT-ARCHITECTURE.md)
- [Doppler config](doppler.yaml)
