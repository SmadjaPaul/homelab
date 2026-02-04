# Instructions de test — OCI Management Stack

**Date** : 2026-02-04  
**Objectif** : Tester le déploiement complet (Terraform → Docker → Tunnel → Services).

---

## Prérequis

- Compte OCI avec compartment OCID
- Cloudflare avec zone `smadja.dev` et compte Zero Trust
- Clé SSH pour OCI
- Token API Cloudflare (pour Terraform)

---

## Étape 1 : Vérifier la configuration Terraform OCI

### 1.1 Vérifier les variables

```bash
cd terraform/oracle-cloud

# Copier l'exemple si nécessaire
cp terraform.tfvars.example terraform.tfvars

# Vérifier que allow_public_http_https = false (ou absent)
grep -E "allow_public_http_https|allow_ssh_from_anywhere" terraform.tfvars || echo "✅ Variables par défaut (sécurisées)"

# Vérifier admin_allowed_cidrs (ton IP publique avec /32)
# Exemple : admin_allowed_cidrs = ["123.45.67.89/32"]
```

### 1.2 Plan Terraform OCI

```bash
cd terraform/oracle-cloud
terraform init
terraform plan

# Vérifier dans le plan :
# - allow_public_http_https = false → pas de règles ingress 80/443
# - SSH seulement depuis admin_allowed_cidrs + GitHub Actions
# - VM management créée avec les bonnes specs
```

### 1.3 Appliquer Terraform OCI

```bash
terraform apply

# Noter l'IP publique de la VM (output ou console OCI)
# Exemple : oci_mgmt_public_ip = "123.45.67.89"
```

---

## Étape 2 : Configurer Cloudflare Tunnel

### 2.1 Créer le tunnel (si pas déjà fait)

**Option A : Via Terraform** (recommandé)

```bash
cd terraform/cloudflare

# Vérifier terraform.tfvars
# - enable_tunnel = true
# - cloudflare_account_id = "ton-account-id"
# - tunnel_secret = "base64-secret" (générer : openssl rand -base64 32)

terraform init
terraform plan  # Vérifier que auth + omni → localhost:8080
terraform apply
```

**Option B : Via Dashboard Cloudflare**

1. Cloudflare Zero Trust → Networks → Tunnels → Create tunnel
2. Nom : `homelab-tunnel`
3. Copier le **token** (pour `.env` plus tard)
4. Public Hostname :
   - `auth.smadja.dev` → `http://localhost:8080`
   - `omni.smadja.dev` → `http://localhost:8080`

### 2.2 Vérifier les routes du tunnel

```bash
# Si tunnel géré par Terraform
cd terraform/cloudflare
terraform output tunnel_info

# Ou dans Cloudflare Dashboard → Tunnels → homelab-tunnel → Public Hostname
# Vérifier : auth et omni pointent vers localhost:8080
```

---

## Étape 3 : Déployer la stack Docker

### 3.1 Préparer les secrets

```bash
# Sur ta machine locale (ou dans GitHub Secrets pour CI)
cd docker/oci-mgmt

# Créer .env (ne pas commiter)
cat > .env << EOF
CLOUDFLARE_TUNNEL_TOKEN=<token-du-tunnel>
POSTGRES_PASSWORD=$(openssl rand -base64 32)
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60)
AUTHENTIK_PUBLIC_URL=https://auth.smadja.dev
AUTHENTIK_OUTPOST_TOKEN=<vide-pour-linstant>
OMNI_ACCOUNT_ID=homelab
OMNI_NAME=Homelab Omni
EOF
```

### 3.2 Déployer via GitHub Actions (recommandé)

```bash
# Push sur main déclenche le workflow
git add docker/oci-mgmt/ terraform/cloudflare/ terraform/authentik/
git commit -m "feat: Add Traefik as single entrypoint"
git push origin main

# Ou déclencher manuellement :
# GitHub → Actions → Deploy OCI Management Stack → Run workflow
```

**Vérifier dans les logs GitHub Actions** :
- ✅ VM trouvée (IP récupérée depuis Terraform state)
- ✅ Ansible déploie docker/oci-mgmt
- ✅ Conteneurs démarrés

### 3.3 Déployer manuellement (alternative)

```bash
# SSH sur la VM OCI
ssh ubuntu@<IP_VM>

# Cloner ou copier le repo
cd ~/homelab/oci-mgmt  # ou le chemin configuré par Ansible

# Vérifier .env
cat .env | grep -v PASSWORD | grep -v TOKEN

# Démarrer
docker compose up -d

# Vérifier les conteneurs
docker compose ps
# Doit montrer : traefik, cloudflared, authentik-server, omni, postgres, redis, outpost
```

---

## Étape 4 : Tests de sécurité (aucun port ouvert)

### 4.1 Depuis l'extérieur (ton ordinateur)

```bash
# Récupérer l'IP publique de la VM
VM_IP=$(cd terraform/oracle-cloud && terraform output -raw oci_mgmt_public_ip 2>/dev/null || echo "123.45.67.89")

# Tester que les ports sont fermés
echo "Test port 80..."
curl -v --max-time 5 http://$VM_IP:80 || echo "✅ Port 80 fermé (timeout/refused)"

echo "Test port 443..."
curl -v --max-time 5 https://$VM_IP:443 || echo "✅ Port 443 fermé (timeout/refused)"

echo "Test port 8080..."
curl -v --max-time 5 http://$VM_IP:8080 || echo "✅ Port 8080 fermé (timeout/refused)"

# SSH doit fonctionner (si ton IP est dans admin_allowed_cidrs)
ssh -o ConnectTimeout=5 ubuntu@$VM_IP "echo 'SSH OK'" || echo "⚠️ SSH bloqué (normal si IP pas dans whitelist)"
```

**Résultat attendu** : Tous les ports HTTP/HTTPS doivent être fermés (timeout ou connection refused).

### 4.2 Depuis la VM (localhost)

```bash
# SSH sur la VM
ssh ubuntu@<IP_VM>

# Vérifier UFW
sudo ufw status
# Doit montrer : 22/tcp ALLOW, pas de 80/443

# Vérifier les ports en écoute
sudo ss -tlnp | grep -E ":(80|443|8080|9000|9001)"
# Doit montrer seulement : 127.0.0.1:8080 (Traefik)

# Tester Traefik localement
curl -H "Host: auth.smadja.dev" http://127.0.0.1:8080 -v
# Doit retourner 200 (Authentik) ou 302 (redirect)

curl -H "Host: omni.smadja.dev" http://127.0.0.1:8080 -v
# Doit retourner 401/302 (Forward Auth) ou 200 si déjà authentifié
```

---

## Étape 5 : Tests fonctionnels (via Tunnel)

### 5.1 Vérifier le tunnel

```bash
# Sur la VM
docker compose logs cloudflared | tail -20
# Doit montrer : "Connection established" ou "Connected to edge"

# Depuis l'extérieur (ton ordinateur)
curl -I https://auth.smadja.dev
# Doit retourner 200 ou 302 (pas de timeout)
```

### 5.2 Tester Authentik

```bash
# Ouvrir dans le navigateur
open https://auth.smadja.dev

# Ou curl
curl -L https://auth.smadja.dev/if/flow/initial-setup/
# Doit retourner la page de setup Authentik

# Après setup initial :
# 1. Créer un compte admin
# 2. Ajouter ton utilisateur au groupe "admin" (Directory → Groups → admin)
```

### 5.3 Configurer Authentik pour Omni (Terraform)

```bash
# Sur ta machine locale
cd terraform/authentik

# Configurer les variables d'environnement
export AUTHENTIK_URL="https://auth.smadja.dev"
export AUTHENTIK_TOKEN="<token-api-authentik>"  # Créer dans Authentik : Directory → Tokens

# Plan
terraform init
terraform plan
# Vérifier : Application Omni + Provider (forward_single) créés

# Apply
terraform apply

# Dans Authentik Dashboard :
# 1. Outposts → default-outpost (ou créer)
# 2. Assigner le provider "omni-proxy"
# 3. Copier le token de l'outpost
```

### 5.4 Mettre à jour le token outpost

```bash
# Sur la VM
cd ~/homelab/oci-mgmt

# Éditer .env
nano .env
# Ajouter : AUTHENTIK_OUTPOST_TOKEN=<token-copié>

# Redémarrer l'outpost
docker compose restart authentik-outpost-proxy

# Vérifier les logs
docker compose logs authentik-outpost-proxy | tail -20
# Doit montrer : "Connected to authentik" ou similaire
```

### 5.5 Tester Omni (avec Forward Auth)

```bash
# Dans le navigateur
open https://omni.smadja.dev

# Comportement attendu :
# 1. Redirection vers Authentik (login)
# 2. Après login → redirection vers Omni
# 3. Omni accessible (si tu es dans le groupe "admin")

# Ou curl (doit retourner 302 vers auth)
curl -I https://omni.smadja.dev
# Location: https://auth.smadja.dev/...
```

---

## Étape 6 : Vérifications finales

### 6.1 Checklist sécurité

- [ ] Port 80 fermé depuis l'extérieur
- [ ] Port 443 fermé depuis l'extérieur
- [ ] Port 8080 fermé depuis l'extérieur
- [ ] SSH fonctionne (si IP dans whitelist)
- [ ] Traefik écoute seulement sur 127.0.0.1:8080
- [ ] Tunnel Cloudflare connecté
- [ ] auth.smadja.dev accessible via HTTPS
- [ ] omni.smadja.dev redirige vers Authentik

### 6.2 Logs à vérifier

```bash
# Sur la VM
cd ~/homelab/oci-mgmt

# Logs Traefik
docker compose logs traefik | tail -30

# Logs cloudflared
docker compose logs cloudflared | tail -30

# Logs Authentik
docker compose logs authentik-server | tail -30

# Logs Outpost
docker compose logs authentik-outpost-proxy | tail -30

# Logs Omni
docker compose logs omni | tail -30
```

---

## Dépannage

### Tunnel ne se connecte pas

```bash
# Vérifier le token
docker compose exec cloudflared env | grep TUNNEL_TOKEN

# Vérifier les routes dans Cloudflare Dashboard
# auth + omni doivent pointer vers localhost:8080
```

### Traefik retourne 502

```bash
# Vérifier que les services sont up
docker compose ps

# Vérifier les routes Traefik
docker compose exec traefik cat /etc/traefik/dynamic/routes.yml

# Tester depuis Traefik vers les backends
docker compose exec traefik wget -O- http://authentik-server:9000
docker compose exec traefik wget -O- http://omni:8080
```

### Forward Auth ne fonctionne pas

```bash
# Vérifier le token outpost
docker compose exec authentik-outpost-proxy env | grep AUTHENTIK_TOKEN

# Vérifier que le provider est assigné à l'outpost dans Authentik UI
# Outposts → default-outpost → Providers → omni-proxy doit être coché

# Logs outpost
docker compose logs authentik-outpost-proxy | grep -i error
```

---

## Résultat attendu

✅ **Aucun port ouvert sur Internet**  
✅ **Tout le trafic passe par Cloudflare Tunnel**  
✅ **auth.smadja.dev accessible**  
✅ **omni.smadja.dev protégé par Forward Auth**
