---
sidebar_position: 3
---

# Rotate Secrets

## Fréquence recommandée

| Secret | Fréquence |
|--------|-----------|
| API tokens | 90 jours |
| Database passwords | 180 jours |
| SSH keys | 1 an |
| TLS certificates | Auto (cert-manager) |

## Cloudflare API Token

### 1. Créer un nouveau token

1. Aller sur https://dash.cloudflare.com/profile/api-tokens
2. Créer un nouveau token avec les mêmes permissions
3. Sauvegarder le token

### 2. Mettre à jour le secret

```bash
# Déchiffrer
sops -d secrets/cloudflare.enc.yaml > secrets/cloudflare.yaml

# Éditer avec le nouveau token
# Puis rechiffrer
sops -e secrets/cloudflare.yaml > secrets/cloudflare.enc.yaml
rm secrets/cloudflare.yaml

# Commit
git add secrets/cloudflare.enc.yaml
git commit -m "Rotate Cloudflare API token"
git push
```

### 3. Mettre à jour dans K8s

```bash
# Si External Secrets Operator
# Le secret sera mis à jour automatiquement

# Sinon, appliquer manuellement
sops -d secrets/cloudflare.enc.yaml | kubectl apply -f -

# Restart les pods qui utilisent le secret
kubectl rollout restart deploy/cloudflared -n cloudflared
kubectl rollout restart deploy/external-dns -n external-dns
```

### 4. Supprimer l'ancien token

1. Retourner sur Cloudflare
2. Supprimer l'ancien token

## Oracle Cloud API Key

### 1. Générer une nouvelle clé

```bash
# Générer
openssl genrsa -out ~/.oci/oci_api_key_new.pem 2048
openssl rsa -pubout -in ~/.oci/oci_api_key_new.pem -out ~/.oci/oci_api_key_new_public.pem

# Afficher la clé publique
cat ~/.oci/oci_api_key_new_public.pem
```

### 2. Uploader dans OCI

1. Console OCI → Profile → API Keys
2. Add API Key
3. Coller la clé publique
4. Noter le nouveau fingerprint

### 3. Mettre à jour la config

```bash
# ~/.oci/config
fingerprint=<nouveau-fingerprint>
key_file=~/.oci/oci_api_key_new.pem
```

### 4. Mettre à jour GitHub Secrets

1. GitHub → Settings → Secrets
2. Mettre à jour `OCI_KEY_FILE`
3. Mettre à jour `OCI_FINGERPRINT`

### 5. Tester

```bash
oci iam user get --user-id $USER_OCID
terraform plan
```

### 6. Supprimer l'ancienne clé

1. Console OCI → API Keys
2. Supprimer l'ancienne clé

## Database Passwords

### PostgreSQL (Keycloak)

```bash
# 1. Générer un nouveau password
NEW_PASS=$(openssl rand -base64 24)

# 2. Se connecter à la DB
kubectl exec -it keycloak-postgresql-0 -n keycloak -- psql -U keycloak

# 3. Changer le password
ALTER USER keycloak WITH PASSWORD 'new-password';

# 4. Mettre à jour le secret K8s
kubectl create secret generic keycloak-db-credentials -n keycloak \
  --from-literal=password=$NEW_PASS \
  --dry-run=client -o yaml | kubectl apply -f -

# 5. Restart Keycloak
kubectl rollout restart deploy/keycloak -n keycloak
```

## Keycloak Admin Password

```bash
# 1. Se connecter à Keycloak admin
open https://auth.smadja.dev/admin

# 2. Users → admin → Credentials
# 3. Set Password

# 4. Mettre à jour le secret (si stocké)
```

## SOPS Age Key

:::warning
Ne pas faire en production sans plan de migration!
:::

```bash
# 1. Générer une nouvelle clé
age-keygen -o ~/.config/sops/age/keys-new.txt

# 2. Re-chiffrer tous les secrets avec les deux clés
# .sops.yaml doit avoir les deux clés temporairement

# 3. Tester le déchiffrement avec la nouvelle clé

# 4. Supprimer l'ancienne clé
```

## Vérification

Après rotation :

1. [ ] Services toujours fonctionnels
2. [ ] CI/CD passe
3. [ ] Pas d'alertes
4. [ ] Anciennes clés supprimées
