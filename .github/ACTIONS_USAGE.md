# Utilisation des Actions GitHub

## Actions utilisées (à conserver)

### 1. `authentik-private-key-jwt-auth` ✅ **NÉCESSAIRE**
- **Utilisée dans** :
  - `terraform-authentik.yml` (job apply) - Méthode principale
  - `authentik-rotate-keys.yml` - Vérification après rotation
  - `omni-gitops.yml` - Authentification pour Omni
- **Statut** : Action principale pour l'authentification Authentik

### 2. `authentik-oauth2-auth` ⚠️ **DEPRECATED - Fallback temporaire**
- **Utilisée dans** :
  - `terraform-authentik.yml` (job plan) - Fallback si `private_key_jwt` échoue
  - `terraform-authentik.yml` (job apply) - Fallback si `private_key_jwt` échoue
- **Statut** : **DEPRECATED** - Conservée temporairement comme fallback de sécurité pendant la période de transition vers `private_key_jwt`
- **Action recommandée** : Une fois que tout fonctionne de manière stable avec `private_key_jwt` (après quelques semaines), supprimer les fallbacks et cette action
- **Migration effectuée** : ✅ Le job `plan` a été migré vers `private_key_jwt` (2026-02-04)

### 3. `generate-rsa-keypair` ✅ **NÉCESSAIRE**
- **Utilisée dans** :
  - `authentik-deploy-jwks.yml` - Génération initiale des clés
  - `authentik-rotate-keys.yml` - Génération de nouvelles clés pour rotation
- **Statut** : Essentielle pour la gestion des clés RSA

### 4. `oci-vault-secrets` ✅ **NÉCESSAIRE**
- **Utilisée dans** :
  - `authentik-deploy-jwks.yml`
  - `terraform-authentik.yml`
  - `authentik-rotate-keys.yml`
  - `omni-gitops.yml`
  - `deploy-oci-mgmt.yml`
- **Statut** : Action centrale pour récupérer les secrets depuis OCI Vault

### 5. `oci-vault-update-secret` ✅ **NÉCESSAIRE**
- **Utilisée dans** :
  - `authentik-deploy-jwks.yml` - Stocker la clé privée
  - `terraform-authentik.yml` - Mettre à jour les secrets après Terraform apply
  - `authentik-rotate-keys.yml` - Stocker la nouvelle clé privée
- **Statut** : Essentielle pour la gestion des secrets dans OCI Vault

### 6. `oci-oidc-auth` ✅ **NÉCESSAIRE**
- **Utilisée dans** :
  - `deploy-oci-mgmt.yml` - Authentification OCI pour déploiement
  - `terraform-oci.yml` - Authentification OCI pour Terraform (4 jobs)
- **Statut** : Essentielle pour l'authentification OCI (pas Authentik, donc différente)

## Actions deprecated (à supprimer après validation)

### `authentik-oauth2-auth` - **DEPRECATED - Fallback temporaire**

**Utilisation actuelle** :
1. Job `plan` dans `terraform-authentik.yml` - Fallback si `private_key_jwt` échoue
2. Job `apply` dans `terraform-authentik.yml` - Fallback si `private_key_jwt` échoue

**Migration effectuée** :
- ✅ Job `plan` migré vers `private_key_jwt` (2026-02-04)
- ✅ Job `apply` utilise déjà `private_key_jwt` comme méthode principale

**Plan de suppression** :
1. ✅ **FAIT** : Migrer le job `plan` pour utiliser `private_key_jwt` au lieu de `client_secret`
2. **À FAIRE** : Valider que tout fonctionne de manière stable avec `private_key_jwt` pendant quelques semaines
3. **À FAIRE** : Supprimer les fallbacks dans les jobs `plan` et `apply`
4. **À FAIRE** : Supprimer l'action `authentik-oauth2-auth` et le secret `authentik_oauth2_client_secret` dans OCI Vault

**Note** : Le fallback est conservé temporairement pour la sécurité pendant la période de transition. Une fois que tout est validé, il sera supprimé.
