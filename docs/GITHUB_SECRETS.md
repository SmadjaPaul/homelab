# Secrets GitHub Requis

Ce document liste tous les secrets nécessaires pour le déploiement via GitHub Actions.

## Configuration

1. Allez dans votre repository GitHub
2. Cliquez sur **Settings** → **Secrets and variables** → **Actions**
3. Cliquez sur **New repository secret**
4. Ajoutez chaque secret un par un

## Secrets Obligatoires

### 🔑 Cloudflare

| Secret | Description | Comment l'obtenir |
|--------|-------------|-------------------|
| `CLOUDFLARE_API_TOKEN` | Token API Cloudflare | Cloudflare Dashboard → My Profile → API Tokens → Create Token → Edit zone DNS |
| `CLOUDFLARE_ZONE_ID` | ID de la zone DNS | Cloudflare Dashboard → Domain → Overview → Zone ID (sidebar) |
| `CLOUDFLARE_ACCOUNT_ID` | ID du compte | Cloudflare Dashboard → sidebar en bas |
| `CLOUDFLARE_TUNNEL_SECRET` | Secret du tunnel | Générer: `openssl rand -base64 32` |
| `CLOUDFLARE_TUNNEL_ID` | ID du tunnel (optionnel) | Laisser vide pour en créer un nouveau |

### 🏢 OCI (Oracle Cloud Infrastructure)

| Secret | Description | Comment l'obtenir |
|--------|-------------|-------------------|
| `OCI_COMPARTMENT_ID` | OCID du compartment | OCI Console → Identity → Compartments → Copier l'OCID |
| `OCI_USER_OCID` | OCID de l'utilisateur | OCI Console → Profile → User Settings → OCID |
| `OCI_CLI_USER` | Nom d'utilisateur OCI | Généralement votre email |
| `OCI_CLI_TENANCY` | OCID du tenancy | Même que OCI_COMPARTMENT_ID (root) |
| `OCI_CLI_FINGERPRINT` | Fingerprint de la clé API | OCI Console → Profile → API Keys → Copier le fingerprint |
| `OCI_CLI_KEY_CONTENT` | Contenu de la clé privée API | Contenu du fichier ~/.oci/oci_api_key.pem |

### 🔐 SSH & Authentification

| Secret | Description | Comment l'obtenir |
|--------|-------------|-------------------|
| `SSH_PUBLIC_KEY` | Clé SSH publique | `cat ~/.ssh/oci-homelab.pub` |
| `SSH_PRIVATE_KEY` | Clé SSH privée (optionnel) | `cat ~/.ssh/oci-homelab` (pour debug SSH) |
| `TAILSCALE_AUTH_KEY` | Clé d'authentification Tailscale | Tailscale Admin Console → Settings → Keys → Auth Keys → Generate |

### 🎛️ Omni (Sidero Labs)

| Secret | Description | Comment l'obtenir |
|--------|-------------|-------------------|
| `OMNI_ENDPOINT` | URL de votre instance Omni | Ex: `https://xxx.omni.siderolabs.io:50001` |
| `OMNI_KEY` | Clé API Omni | Omni UI → Settings → Keys → Generate |

### 🔒 Authentik (optionnel pour le moment)

| Secret | Description | Comment l'obtenir |
|--------|-------------|-------------------|
| `AUTHENTIK_OIDC_CLIENT_ID` | Client ID OAuth | Sera généré après déploiement d'Authentik |
| `AUTHENTIK_OIDC_CLIENT_SECRET` | Client Secret OAuth | Sera généré après déploiement d'Authentik |
| `AUTHENTIK_OIDC_AUTH_URL` | URL d'autorisation | `https://auth.smadja.dev/application/o/authorize/` |
| `AUTHENTIK_OIDC_TOKEN_URL` | URL des tokens | `https://auth.smadja.dev/application/o/token/` |
| `AUTHENTIK_OIDC_CERTS_URL` | URL des certificats | `https://auth.smadja.dev/application/o/<app>/jwks/` |

### 📧 Divers

| Secret | Description | Exemple |
|--------|-------------|---------|
| `ALERT_EMAIL` | Email pour les alertes | `admin@smadja.dev` |
| `ALLOWED_EMAILS` | Emails autorisés pour Cloudflare Access | `user1@example.com,user2@example.com` |
| `ENABLE_GEO_RESTRICTION` | Activer la restriction géo | `true` ou `false` |
| `DOPPLER_TOKEN` | Token de service Doppler | `dp.st.xxx` (projet infrastructure) |

## Environments GitHub

Créez aussi ces environnements avec protection:

1. **cloudflare** - Pour les modifications Cloudflare
2. **production** - Pour les VMs OCI
3. **omni** - Pour le bootstrap Kubernetes
4. **kubernetes** - Pour le déploiement des applications

### Configuration des Environments

Pour chaque environment:
1. Settings → Environments → New environment
2. Nom: `cloudflare`, `production`, `omni`, ou `kubernetes`
3. Protection rules:
   - ✅ Required reviewers: 1 personne (vous)
   - ✅ Wait timer: 0 minutes
   - (Optionnel) Deployment branches: Restricted to selected branches → main

## Vérification

Une fois tous les secrets configurés, vous pouvez vérifier avec ce workflow de test:

```yaml
name: Test Secrets
on: workflow_dispatch
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Check Secrets
        run: |
          # Ne pas afficher les valeurs, juste vérifier qu'elles existent
          [ -n "${{ secrets.CLOUDFLARE_API_TOKEN }}" ] && echo "✅ CLOUDFLARE_API_TOKEN" || echo "❌ CLOUDFLARE_API_TOKEN"
          [ -n "${{ secrets.OCI_COMPARTMENT_ID }}" ] && echo "✅ OCI_COMPARTMENT_ID" || echo "❌ OCI_COMPARTMENT_ID"
          [ -n "${{ secrets.OMNI_ENDPOINT }}" ] && echo "✅ OMNI_ENDPOINT" || echo "❌ OMNI_ENDPOINT"
          # etc...
```

## Sécurité

⚠️ **IMPORTANT**:
- Ne jamais commiter ces secrets dans le repository
- Utilisez toujours `secrets.*` dans les workflows
- Régénérez les tokens régulièrement
- Utilisez des tokens avec le minimum de permissions nécessaires
- Activez 2FA sur tous les comptes (GitHub, Cloudflare, OCI, etc.)

## Dépannage

### "Secret not found"
Vérifiez l'orthographe du nom du secret (sensible à la casse).

### "Permission denied" sur OCI
Vérifiez que:
- La clé API est correctement configurée dans OCI
- La clé privée correspond au fingerprint
- L'utilisateur a les permissions nécessaires sur le compartment

### "Invalid API token" sur Cloudflare
Vérifiez que:
- Le token a les permissions "Zone:Read" et "DNS:Edit"
- Le token est actif (pas expiré)
- Le token est pour la bonne zone (domaine)

### "Cannot connect to Omni"
Vérifiez que:
- L'endpoint est complet avec le port: `https://xxx.omni.siderolabs.io:50001`
- La clé API est valide et n'a pas expiré
- Votre instance Omni est en ligne
