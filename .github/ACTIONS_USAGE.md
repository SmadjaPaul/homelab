# Utilisation des Actions GitHub

## Actions utilisées

### 1. `authentik-oauth2-auth`
- **Utilisée dans** : `omni-gitops.yml` — authentification OAuth2 (client_credentials) ou token statique pour omnictl.
- **Statut** : Utilisée pour Omni ; Terraform Authentik utilise uniquement le token statique.

### 2. `oci-vault-secrets`
- **Utilisée dans** : `terraform-authentik.yml`, `omni-gitops.yml`, `deploy-oci-mgmt.yml`, etc.
- **Statut** : Récupération des secrets depuis OCI Vault (dont `authentik_token`, `authentik_oauth2_client_id`, `authentik_oauth2_client_secret`).

### 3. `oci-vault-update-secret`
- **Utilisée dans** : `terraform-authentik.yml` — mise à jour des secrets OAuth2 après apply.
- **Statut** : Mise à jour des secrets dans OCI Vault.

### 4. `oci-oidc-auth`
- **Utilisée dans** : `deploy-oci-mgmt.yml`, `terraform-oci.yml`.
- **Statut** : Authentification OCI (OIDC).

### 5. `generate-rsa-keypair`
- **Utilisée dans** : aucune (workflows JWKS supprimés). Conservée au cas où.
- **Statut** : Optionnelle.

### 6. `terraform-force-unlock`
- **Utilisée dans** : `terraform-authentik.yml`.
- **Statut** : Déblocage du state Terraform si nécessaire.

## Authentik en CI

- **Terraform Authentik** : token statique uniquement (`AUTHENTIK_TOKEN` depuis GitHub Secrets ou OCI Vault `homelab-authentik-token`).
- **Omni GitOps** : OAuth2 client_credentials (client_id/secret dans OCI Vault) ou token statique en fallback.
