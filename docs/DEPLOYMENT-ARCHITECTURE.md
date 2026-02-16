# Architecture de Déploiement - Dépendances & Bootstrap

## 🚨 Problème de Dépendances Identifié

### Le Piège "Omni ↔ Authentik"

```
❌ Mauvais ordre:
Omni (configuré avec Authentik) → Cluster K8s → Authentik
                                  ↑
                                  └── Blocage! Omni refuse connexion
                                      car Authentik n'existe pas encore

✅ Bon ordre:
Omni (auth locale) → Cluster K8s → Authentik → Configurer Authentik
                                        ↓
                                        └── Puis optionnel: migrer Omni
                                            vers Authentik (ou garder local)
```

## 📋 Ordre de Déploiement Corrigé

### Phase 0 : Prérequis (Local)

```bash
# 1. Installer outils
brew install terraform kubectl helm talosctl doppler

# 2. Doppler setup
./scripts/setup-doppler.sh
# → Crée tous les projets
# → Génère les tokens
# → Stocke dans 'infrastructure'

# 3. Configurer secrets dans Doppler
# infrastructure:
#   - OCI_CLI_*
#   - CLOUDFLARE_API_TOKEN
#   - TAILSCALE_AUTH_KEY
#   - GRAFANA_CLOUD_*
#   - DOPPLER_TOKEN_SERVICE_* (auto-générés)
#
# service-authentik: (laisser vide pour l'instant)
# service-nextcloud: (laisser vide pour l'instant)
# etc.
```

### Phase 1 : Infrastructure Terraform

```bash
cd terraform/oracle-cloud

# Variables minimales dans terraform.tfvars:
# - compartment_id
# - ssh_public_key
# - tailscale_auth_key (optionnel pour l'instant)
# - cloudflare_tunnel_token (optionnel pour l'instant)

doppler run -- terraform apply
```

**Résultat** :
- ✅ VM Hub : Omni (auth par défaut, locale)
- ✅ 3 VMs Talos (Ubuntu fallback si pas d'image)

### Phase 2 : Configuration Omni (Manuel)

```bash
# 1. SSH sur VM Hub
ssh ubuntu@$(terraform output -raw hub_public_ip)

# 2. Configurer Omni
# Accès: https://$(terraform output -raw hub_public_ip):50001
# - Créer utilisateur admin local (pas besoin d'Authentik!)
# - Générer clé Omni
# - Créer cluster "oci-hub"

# 3. Générer image Talos
# Omni UI → Download → Oracle Cloud → Récupérer OCID

# 4. Mettre à jour terraform.tfvars
echo 'talos_image_id = "ocid1.image.oc1.xxxx"' >> terraform.tfvars

# 5. Re-appliquer pour déployer Talos sur les VMs
doppler run -- terraform apply
```

**Résultat** :
- ✅ Cluster K8s opérationnel
- ✅ Omni fonctionne avec auth locale

### Phase 3 : Bootstrap Kubernetes (GitOps)

```bash
# 1. Récupérer kubeconfig
omnictl kubeconfig -c oci-hub > ~/.kube/config

# 2. Vérifier cluster
kubectl get nodes

# 3. Déployer Flux (manuel - pas dans Git encore)
flux install

# 4. Créer secret Doppler (infrastructure token)
# Récupérer token:
export INFRA_TOKEN=$(doppler configs tokens create prd bootstrap -p infrastructure --plain)

kubectl create secret generic doppler-token-infrastructure \
  --from-literal=dopplerToken="$INFRA_TOKEN" \
  -n flux-system

# 5. Déployer External Secrets Operator
kubectl apply -k kubernetes/apps/infrastructure/external-secrets

# 6. Vérifier que les stores sont créés
kubectl get clustersecretstores
```

**Résultat** :
- ✅ External Secrets Operator fonctionne
- ✅ Peut récupérer secrets depuis Doppler

### Phase 4 : Infrastructure Core (GitOps)

```bash
# 1. Ajouter dans kubernetes/clusters/oci-hub/kustomization.yaml:
# resources:
#   - ../../apps/infrastructure/cert-manager
#   - ../../apps/infrastructure/cloudflare-tunnel
#   - ../../apps/infrastructure/traefik

# 2. Pousser sur Git
git add .
git commit -m "Add core infrastructure"
git push

# 3. Appliquer
kubectl apply -k kubernetes/clusters/oci-hub

# 4. Vérifier
kubectl get pods -n infra
```

**Résultat** :
- ✅ Cert-manager (certificats TLS)
- ✅ Cloudflare Tunnel (accès public)
- ✅ Traefik (ingress)

### Phase 5 : Authentik (Première App)

```bash
# 1. Créer projet Doppler 'service-authentik'
# Ajouter secrets:
# - AUTHENTIK_SECRET_KEY
# - AUTHENTIK_BOOTSTRAP_PASSWORD
# - AUTHENTIK_BOOTSTRAP_TOKEN
# - AUTHENTIK_POSTGRES_PASSWORD
# - SMTP_* (optionnel)

# 2. Créer dans kubernetes/apps/business/authentik/
# - helmrelease.yaml
# - external-secret.yaml
# - values.yaml (config)

# 3. Ajouter à kustomization.yaml

# 4. Pousser sur Git
# Flux déploie automatiquement

# 5. Vérifier
kubectl get pods -n business
kubectl logs -n business deployment/authentik-server
```

**Résultat** :
- ✅ Authentik déployé
- ✅ Accessible via auth.smadja.dev

### Phase 6 : Configuration Authentik (Manuel)

```bash
# 1. Accéder à https://auth.smadja.dev
# 2. Se connecter avec bootstrap password
# 3. Créer:
#    - Utilisateurs (toi, famille)
#    - Groupes (admin, family)
#    - Applications (pour chaque service)
#    - Provider OIDC pour les apps

# 4. Optionnel: Configurer Omni pour utiliser Authentik
# Omni UI → Auth → OIDC
# Mais ATTENTION: garder un admin local en backup!
```

### Phase 7 : Apps Successives

Pour chaque app (Nextcloud, Matrix, etc.) :

```bash
# 1. Créer projet Doppler (ex: service-nextcloud)
# 2. Ajouter secrets dans Doppler
# 3. Créer dossier kubernetes/apps/productivity/nextcloud/
# 4. HelmRelease + ExternalSecret
# 5. Ajouter route dans cloudflare-tunnel/helmrelease.yaml
# 6. Pousser sur Git
# 7. Flux déploie automatiquement
# 8. Configurer dans Authentik (provider + app)
```

## ⚠️ Points de Blocage Potentiels

### 1. Omni sans Authentik

**Problème** : Si on configure Omni avec Authentik avant qu'il existe → blocage

**Solution** :
- Omni utilise auth locale pendant le bootstrap
- Une fois Authentik déployé, on PEUT migrer (optionnel)
- Mais toujours garder un admin local!

### 2. External Secrets sans Doppler

**Problème** : Si le token Doppler est invalide → aucun secret ne se sync

**Solution** :
- Vérifier token avant déploiement
- Avoir un fallback manuel possible

```bash
# Si ESO ne fonctionne pas, fallback manuel:
kubectl create secret generic authentik-secrets \
  --from-literal=AUTHENTIK_SECRET_KEY="xxx" \
  -n business
```

### 3. Cert-manager sans Cloudflare

**Problème** : Si le token CF DNS est invalide → pas de certificats

**Solution** :
- Vérifier token avant
- Utiliser certificats auto-signés temporairement

### 4. Cloudflare Tunnel sans Ingress

**Problème** : Tunnel configuré mais service n'existe pas encore

**Solution** :
- Pas de blocage, juste 404
- L'ordre n'est pas critique

### 5. Apps sans Authentik

**Problème** : App déployée mais pas encore dans Authentik

**Solution** :
- Déployer apps avec auth désactivée d'abord
- Ou utiliser middleware Traefik pour forward auth

## 🔄 Workflow Déploiement - Résumé

```
Phase 0: Prérequis
  └─ Doppler, outils CLI

Phase 1: Terraform
  └─ 4 VMs (Omni + 3 Talos)

Phase 2: Omni Setup (Manuel)
  └─ Créer cluster
  └─ Générer image Talos
  └─ Re-apply Terraform

Phase 3: K8s Bootstrap (Manuel)
  └─ Flux install
  └─ Secret Doppler
  └─ External Secrets Operator

Phase 4: Infra Core (GitOps)
  └─ Cert-manager
  └─ Cloudflare Tunnel
  └─ Traefik

Phase 5: Authentik (GitOps + Manuel)
  └─ Déployer (GitOps)
  └─ Configurer (Manuel)

Phase 6+: Apps (GitOps)
  └─ Nextcloud, Matrix, etc.
```

## 📁 Fichiers Critiques

### Bootstrap Manuel (Phase 2-3)

```bash
# scripts/bootstrap-phase2.sh
#!/bin/bash
# Configuration Omni post-Terraform

set -e

HUB_IP=$(terraform -chdir=terraform/oracle-cloud output -raw hub_public_ip)

echo "=== Phase 2: Omni Configuration ==="
echo "1. Accéder à https://$HUB_IP:50001"
echo "2. Créer utilisateur admin"
echo "3. Créer cluster 'oci-hub'"
echo "4. Générer image Talos"
echo ""
echo "Puis mettre à jour terraform.tfvars:"
echo "talos_image_id = \"<OCID>\""
echo ""
echo "Appuyez sur une touche quand c'est fait..."
read -n 1

echo "=== Phase 3: Kubernetes Bootstrap ==="
omnictl kubeconfig -c oci-hub > ~/.kube/config
kubectl get nodes

export INFRA_TOKEN=$(doppler configs tokens create prd bootstrap -p infrastructure --plain 2>/dev/null || doppler configs tokens create prd bootstrap-$(date +%s) -p infrastructure --plain)

kubectl create secret generic doppler-token-infrastructure \
  --from-literal=dopplerToken="$INFRA_TOKEN" \
  -n flux-system

flux install
kubectl apply -k kubernetes/apps/infrastructure/external-secrets

echo "✅ Bootstrap terminé"
echo "Prochaine étape: Phase 4 (GitOps)"
echo "  kubectl apply -k kubernetes/clusters/oci-hub"
```

### Checklist Déploiement

```markdown
## Phase 0 - Prérequis
- [ ] Doppler CLI installé
- [ ] Terraform installé
- [ ] kubectl installé
- [ ] talosctl installé
- [ ] Scripts Doppler exécutés
- [ ] Secrets OCI dans Doppler

## Phase 1 - Terraform
- [ ] terraform.tfvars créé
- [ ] `terraform apply` réussi
- [ ] 4 VMs créées

## Phase 2 - Omni Setup
- [ ] Accès Omni Web UI
- [ ] Utilisateur admin créé
- [ ] Cluster "oci-hub" créé
- [ ] Image Talos générée
- [ ] talos_image_id mis à jour
- [ ] Re-apply Terraform

## Phase 3 - K8s Bootstrap
- [ ] kubeconfig récupéré
- [ ] Nodes visibles (kubectl get nodes)
- [ ] Flux installé
- [ ] Secret Doppler créé
- [ ] External Secrets Operator déployé

## Phase 4 - Infra Core
- [ ] Cert-manager Running
- [ ] Cloudflare Tunnel Running
- [ ] Traefik Running
- [ ] Certificats TLS générés

## Phase 5 - Authentik
- [ ] Projet Doppler créé
- [ ] Secrets ajoutés
- [ ] HelmRelease poussé sur Git
- [ ] Pods Running
- [ ] UI accessible
- [ ] Config manuelle faite

## Phase 6+ - Apps
- [ ] Nextcloud
- [ ] Matrix
- [ ] ...
```

## 🆘 Rollback en Cas de Problème

### Si Omni bloqué (config auth invalide)

```bash
# Sur VM Hub
sudo docker exec -it omni sh
# Réinitialiser config auth
rm /data/omni.db
# Redémarrer
docker restart omni
```

### Si Cluster K8s inaccessible

```bash
# Redéployer via Omni
omnictl cluster template sync -f cluster-template.yaml

# Ou re-créer les VMs
cd terraform/oracle-cloud
doppler run -- terraform taint oci_core_instance.k8s_node[0]
doppler run -- terraform taint oci_core_instance.k8s_node[1]
doppler run -- terraform taint oci_core_instance.k8s_node[2]
doppler run -- terraform apply
```

### Si Secrets ne se sync pas

```bash
# Vérifier logs ESO
kubectl logs -n flux-system deployment/external-secrets

# Fallback manuel
kubectl create secret generic fallback \
  --from-literal=key=value \
  -n namespace
```
