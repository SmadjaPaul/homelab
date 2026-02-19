# Architecture avec Tailscale - Résolution du Problème de Séquencement

Ce document explique comment utiliser **Tailscale** pour résoudre le problème de dépendance circulaire entre Cloudflare Tunnel et Authentik.

## Le Problème

```
Problème de dépendance circulaire :
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   ┌────────────────────┐        ┌──────────────────────┐   │
│   │  Cloudflare Tunnel │        │     Authentik        │   │
│   │                    │───────►│                      │   │
│   │  (auth.smadja.dev) │        │  (SSO Provider)      │   │
│   └────────────────────┘        └──────────────────────┘   │
│            ▲                              │                 │
│            │                              │                 │
│            └──────────────────────────────┘                 │
│                    Cloudflare Access                        │
│                    (authentique les accès)                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘

Problème :
- Cloudflare Tunnel expose auth.smadja.dev
- Cloudflare Access protège auth.smadja.dev et requiert Authentik
- Terraform configure Authentik via l'API
- Mais l'API est inaccessible car protégée par Cloudflare Access
```

## La Solution : Tailscale

```
Solution avec Tailscale (réseau maillé privé) :
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│   GitHub Actions / Local Machine                                   │
│          │                                                         │
│          │ 1. Se connecte à Tailscale                              │
│          ▼                                                         │
│   ┌──────────────────────────┐                                     │
│   │   Tailscale Network      │                                     │
│   │   (100.x.x.x)            │                                     │
│   └──────────┬───────────────┘                                     │
│              │                                                     │
│              │ 2. Accès direct aux IPs privées                      │
│              ▼                                                     │
│   ┌────────────────────────────────────────────────────────────┐  │
│   │                    Kubernetes Cluster                       │  │
│   │  ┌─────────────────────┐        ┌──────────────────────┐   │  │
│   │  │  Cloudflare Tunnel  │        │     Authentik        │   │  │
│   │  │  (auth.smadja.dev)  │◄───────┤                      │   │  │
│   │  │                     │        │  100.x.x.x:80        │   │  │
│   │  └─────────────────────┘        │  (accès via TS)      │   │  │
│   │                                 └──────────────────────┘   │  │
│   └────────────────────────────────────────────────────────────┘  │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘

Avantage : Terraform peut configurer Authentik via l'IP Tailscale
           sans dépendre du tunnel Cloudflare !
```

## Architecture Complète

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                        │
│                                                                              │
│   Utilisateurs finals ──────► Cloudflare Tunnel ──────► Authentik           │
│   (auth.smadja.dev)        (via Cloudflare Access)    (100.x.x.x)          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       │ Kubernetes
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CLUSTER KUBERNETES                                  │
│                                                                              │
│   ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────┐ │
│   │  Cloudflared         │  │  Authentik Server    │  │  Tailscale       │ │
│   │  (Ingress public)    │  │  10.0.x.x:80         │  │  (100.x.x.x)     │ │
│   │                      │  │                      │  │                  │ │
│   │  - Expose au public  │  │  - OIDC Provider     │  │  - Réseau privé  │ │
│   │  - Via Cloudflare    │  │  - Gestion users     │  │  - Mesh VPN      │ │
│   │                      │  │  - Apps proxy        │  │  - Accès admin   │ │
│   └──────────┬───────────┘  └──────────┬───────────┘  └────────┬─────────┘ │
│              │                         │                       │           │
│              └─────────────────────────┴───────────────────────┘           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         │ Administration
         │ (Tailscale - réseau privé)
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ADMINISTRATEURS                                      │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  Machines autorisées (Tailscale) :                                  │   │
│   │                                                                     │   │
│   │  - Poste local développeur (100.x.x.1)                             │   │
│   │  - GitHub Actions (tag:github-actions)                             │   │
│   │  - Terraform Cloud (si utilisé)                                     │   │
│   │                                                                     │   │
│   │  Accès :                                                            │   │
│   │  - kubectl via API OKE                                              │   │
│   │  - Authentik via 100.x.x.x:80 (bypass Cloudflare)                   │   │
│   │  - Dashboards internes                                              │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Configuration

### 1. Installer Tailscale sur le Cluster Kubernetes

```bash
# Installer Tailscale sur le cluster
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tailscale
  namespace: tailscale
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tailscale
  template:
    metadata:
      labels:
        app: tailscale
    spec:
      serviceAccountName: tailscale
      containers:
      - name: tailscale
        image: tailscale/tailscale:latest
        env:
        - name: TS_AUTHKEY
          valueFrom:
            secretKeyRef:
              name: tailscale-auth
              key: TS_AUTHKEY
        - name: TS_USERSPACE
          value: "false"
        - name: TS_ACCEPT_DNS
          value: "true"
        securityContext:
          privileged: true
EOF
```

### 2. Configurer GitHub Actions avec Tailscale

Le workflow `.github/workflows/terraform.yml` inclut déjà :

```yaml
- name: Connect to Tailscale
  uses: tailscale/github-action@v3
  with:
    oauth-client-id: ${{ secrets.TS_OAUTH_CLIENT_ID }}
    oauth-secret: ${{ secrets.TS_OAUTH_SECRET }}
    tags: tag:github-actions
```

### 3. Secrets GitHub Requis

Ajoutez ces secrets dans votre repository GitHub :

```
TS_OAUTH_CLIENT_ID     # Depuis Tailscale Admin Console
TS_OAUTH_SECRET        # Depuis Tailscale Admin Console
```

### 4. Configuration Doppler

Assurez-vous d'avoir dans Doppler (projet `homelab`, config `prd`) :

```ini
# Authentik
AUTHENTIK_URL=https://auth.smadja.dev         # URL publique
AUTHENTIK_TOKEN=your-api-token                # Token API permanent

# OCI (pour Oracle Cloud)
OCI_TENANCY_OCID=ocid1.tenancy.oc1..xxxx
OCI_CLI_USER=ocid1.user.oc1..xxxx
OCI_CLI_FINGERPRINT=xx:xx:xx:xx
OCI_CLI_KEY_CONTENT=-----BEGIN RSA PRIVATE KEY-----
...
-----END RSA PRIVATE KEY-----
```

## Workflow de Déploiement

### Séquence Idéale avec Tailscale

```
Étape 1 : Oracle Cloud (Infrastructure)
├─ Crée le cluster OKE
├─ Installe Tailscale (récupère IP 100.x.x.x)
└─ Output : IP Tailscale du cluster

Étape 2 : Cloudflare (DNS + Tunnel)
├─ Crée le tunnel Cloudflare
├─ Configure DNS (auth.smadja.dev → tunnel)
└─ Output : Tunnel credentials

Étape 3 : Kubernetes (Applications)
├─ Déploie Authentik via Helm/Flux
├─ Authentik obtient IP 100.x.x.x via Tailscale
├─ Configure Cloudflared pour exposer Authentik
└─ Authentik accessible via :
   • https://auth.smadja.dev (public, via CF Tunnel)
   • http://100.x.x.x:80 (privé, via Tailscale)

Étape 4 : Authentik (Configuration)
├─ Terraform se connecte via Tailscale (100.x.x.x)
├─ Configure users, groups, policies
├─ Crée provider OIDC pour Cloudflare Access
└─ Mise à jour automatique des secrets dans Doppler

Étape 5 : Cloudflare Access (Sécurisation)
├─ Ajoute Authentik comme IdP
├─ Configure applications protégées
└─ Active MFA et policies
```

## Utilisation en Local

### Option 1 : Via Tailscale (Recommandé pour le développement)

```bash
# 1. Se connecter à Tailscale
tailscale up

# 2. Tester la connexion
ping 100.x.x.x  # IP Authentik dans Tailscale

# 3. Utiliser l'IP Tailscale pour Terraform
export TF_VAR_authentik_url="http://100.x.x.x:80"
cd terraform/authentik
terraform apply
```

### Option 2 : Via Port-Forward (Débogage uniquement)

```bash
# 1. Port-forward depuis le cluster
kubectl -n authentik port-forward svc/authentik-server 9000:80

# 2. Utiliser localhost
export TF_VAR_authentik_url="http://localhost:9000"
cd terraform/authentik
terraform apply
```

### Option 3 : Via Cloudflare Tunnel (Production uniquement)

```bash
# Si Cloudflare Access n'est pas encore activé
export TF_VAR_authentik_url="https://auth.smadja.dev"
cd terraform/authentik
terraform apply
```

## Avantages de cette Architecture

1. **Pas de dépendance circulaire** : Terraform peut toujours configurer Authentik
2. **Accès de secours** : Si Cloudflare est down, accès via Tailscale
3. **Sécurité** : Administration uniquement via réseau privé Tailscale
4. **Flexibilité** : Plusieurs méthodes d'accès selon le contexte
5. **CI/CD robuste** : GitHub Actions peut toujours déployer

## Commandes Utiles

```bash
# Voir les machines Tailscale
tailscale status

# Se connecter au cluster OKE via Tailscale
ssh ubuntu@100.x.x.x  # Si configuré

# Accéder à Authentik via Tailscale
curl http://100.x.x.x:80/-/health/ready/

# Vérifier les IPs Tailscale dans Kubernetes
kubectl -n tailscale get pods -o wide

# Logs Tailscale
kubectl -n tailscale logs -l app=tailscale
```

## Troubleshooting

### "Cannot connect to Authentik via Tailscale"

```bash
# Vérifier que Tailscale est connecté
tailscale status

# Vérifier l'IP Authentik
kubectl -n authentik get svc authentik-server -o jsonpath='{.spec.clusterIP}'

# Vérifier que le pod Authentik est healthy
kubectl -n authentik get pods
```

### "GitHub Actions cannot connect"

```bash
# Vérifier les secrets
# - TS_OAUTH_CLIENT_ID doit être créé dans Tailscale Admin Console
# - TS_OAUTH_SECRET doit correspondre

# Vérifier les tags
# La machine GitHub Actions doit avoir le tag 'github-actions'
```

### "Doppler secrets not found"

```bash
# Vérifier les secrets Doppler
doppler secrets -p homelab -c prd

# Si les secrets OCI sont manquants, ils peuvent aussi être passés via variables d'environnement :
export OCI_CLI_USER=ocid1.user.oc1..xxxx
export OCI_CLI_FINGERPRINT=xx:xx:xx
export OCI_CLI_KEY_CONTENT="-----BEGIN..."
export OCI_TENANCY_OCID=ocid1.tenancy.oc1..xxxx
```

## Références

- [Tailscale GitHub Action](https://github.com/tailscale/github-action)
- [Tailscale Kubernetes Documentation](https://tailscale.com/kb/1185/kubernetes/)
- [Authentik Terraform Provider](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)
- [Doppler Terraform Provider](https://registry.terraform.io/providers/DopplerHQ/doppler/latest/docs)

---

**Note** : Cette configuration permet d'éviter le "chicken and egg problem" où Cloudflare Access nécessite Authentik, mais Authentik ne peut pas être configuré sans accès à l'API. Avec Tailscale, vous avez toujours un chemin d'accès privé pour l'administration.
