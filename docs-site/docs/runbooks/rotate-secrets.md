---
sidebar_position: 7
---

# Rotation des secrets

## Fréquence

| Secret | Fréquence |
|--------|-----------|
| API tokens | 90 jours |
| DB passwords | 180 jours |
| SSH keys | 1 an |

## Cloudflare API Token

```bash
# 1. Créer nouveau token sur cloudflare.com
# 2. Mettre à jour le secret
sops -d secrets/cloudflare.enc.yaml > secrets/cloudflare.yaml
# Éditer
sops -e secrets/cloudflare.yaml > secrets/cloudflare.enc.yaml
rm secrets/cloudflare.yaml

# 3. Appliquer
sops -d secrets/cloudflare.enc.yaml | kubectl apply -f -

# 4. Restart
kubectl rollout restart deploy/cloudflared -n cloudflared
```

## Oracle Cloud API Key

```bash
# 1. Générer nouvelle clé
openssl genrsa -out ~/.oci/oci_api_key_new.pem 2048

# 2. Uploader sur OCI Console

# 3. Mettre à jour ~/.oci/config

# 4. Mettre à jour GitHub Secrets
```

## Database Passwords

```bash
# PostgreSQL
kubectl exec -it postgres-0 -n keycloak -- psql -U keycloak
ALTER USER keycloak WITH PASSWORD 'new-password';

# Mettre à jour le secret K8s
# Restart l'application
```

## Vérification

- [ ] Services fonctionnels
- [ ] CI/CD passe
- [ ] Anciennes clés supprimées
