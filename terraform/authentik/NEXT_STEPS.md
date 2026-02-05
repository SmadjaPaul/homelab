# Prochaines étapes - Authentik Terraform

## ✅ Ce qui est en place

1. **Provider OAuth2 `ci-automation`** — créé via Terraform (client_credentials pour Omni GitOps).
2. **Grant type "Client credentials"** — activé automatiquement via `provider_ci_automation_config.tf`.
3. **CI** — Terraform Authentik utilise un token statique (`AUTHENTIK_TOKEN`). Omni GitOps utilise OAuth2 client_id/secret ou token statique.

## 📋 À faire si besoin

### Premier déploiement

1. **Token API Authentik** : Directory → Tokens & App passwords → créer un token.
2. **GitHub** : Settings → Secrets → Actions → `AUTHENTIK_TOKEN` (ou stocker dans OCI Vault : `homelab-authentik-token`).
3. **Outpost** : si l’outpost n’est pas dans l’état Terraform, le workflow affiche les instructions d’import.
4. **Omni** : pour Omni GitOps, stocker `authentik_oauth2_client_id` et `authentik_oauth2_client_secret` dans OCI Vault (outputs Terraform après le premier apply), ou utiliser `AUTHENTIK_TOKEN` en fallback.

### Vérification

- **Authentik UI** : Applications → Providers → `ci-automation` → Grant types → "Client credentials" coché.
- **Terraform** : `cd terraform/authentik && terraform output`

## 📝 Commandes utiles

```bash
cd terraform/authentik
export AUTHENTIK_URL="https://auth.smadja.dev"
export AUTHENTIK_TOKEN="<ton_token>"
terraform plan
terraform apply
```
