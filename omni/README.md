# Omni — config en IaC

Configuration **Omni** (Sidero) pour la gestion des clusters Talos. Préférence **IaC** : MachineClasses et clusters applicables avec **omnictl**, sans passer par l’UI sauf si nécessaire (auth, premier run).

## Structure

| Répertoire / fichier | Rôle |
|----------------------|------|
| `machine-classes/`   | Définitions MachineClass (control-plane, worker, gpu-worker). À appliquer avec `omnictl apply -f ...`. |
| `clusters/`          | Exemple de cluster (ex. `cluster-dev.yaml`) pour `omnictl apply cluster -f ...`. |

## Appliquer la config (IaC)

1. **MachineClasses** : voir [machine-classes/README.md](machine-classes/README.md).
   ```bash
   omnictl apply -f omni/machine-classes/all.yaml
   ```

2. **Cluster** (ex. dev) : après les MachineClasses, créer le cluster à partir du template.
   ```bash
   omnictl apply cluster -f omni/clusters/cluster-dev.yaml
   ```

3. **Enregistrement des machines** : join token (DEV) ou image Oracle (CLOUD) — voir [docs/omni-register-cluster.md](../docs/omni-register-cluster.md). La config Talos (join token) reste en IaC dans `talos/*.yaml`.

## Prérequis omnictl

- **Endpoint** : `https://omni.smadja.dev` (accès via Authentik).
- **Auth** : selon ton setup (SAML/Authentik, token). Voir [Install and Configure Omnictl](https://omni.siderolabs.com/how-to-guides/install-and-configure-omnictl).

## Authentification pour la CI (OIDC via Authentik)

Le workflow GitHub Actions (`.github/workflows/omni-gitops.yml`) utilise **OIDC** pour s'authentifier auprès d'Authentik, puis Authentik authentifie auprès d'Omni. Plus sécurisé qu'un token statique.

### 1. Créer le provider OAuth2 générique dans Authentik (Terraform via CI)

Le provider OAuth2 générique `ci-automation` est créé automatiquement via le workflow `.github/workflows/terraform-authentik.yml` quand tu pushes sur `terraform/authentik/**`.

**Prérequis** : Le secret `AUTHENTIK_TOKEN` doit être configuré dans GitHub Secrets (voir `.github/DEPLOYMENTS.md`).

Cela crée :
- Un provider OAuth2 `ci-automation` (machine-to-machine avec `client_credentials`)
- Une application `CI/CD Automation (GitHub Actions)`
- **Ce provider est utilisé par tous les workflows** : Omni GitOps, Terraform Authentik, ArgoCD, etc.

**Important** : Après le premier `terraform apply` (via CI), activer manuellement le grant type **"Client credentials"** dans Authentik UI :
- **Applications** → **Providers** → `ci-automation` → **Edit**
- Cocher **"Client credentials"** dans **Grant types**
- **Update**

(Cette étape ne peut pas être automatisée via Terraform car le provider Authentik ne l'expose pas dans l'API.)

### 2. Récupérer les outputs Terraform et ajouter aux secrets GitHub

Après `terraform apply`, récupérer les outputs :

```bash
terraform output ci_automation_oauth2_client_id
terraform output -raw ci_automation_oauth2_client_secret
terraform output ci_automation_oauth2_issuer_url
```

Ajouter ces secrets dans GitHub (utilisés par **tous** les workflows CI/CD) :
- Repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**
- **`CI_AUTOMATION_AUTHENTIK_CLIENT_ID`** : valeur de `ci_automation_oauth2_client_id`
- **`CI_AUTOMATION_AUTHENTIK_CLIENT_SECRET`** : valeur de `ci_automation_oauth2_client_secret` (sensitive)
- **`CI_AUTOMATION_AUTHENTIK_ISSUER_URL`** : valeur de `ci_automation_oauth2_issuer_url` (optionnel, défaut utilisé si absent)

### 3. Configurer Omni pour accepter Authentik (SAML/OIDC)

Omni doit être configuré pour utiliser Authentik comme provider d'authentification :

1. **Activer SAML/OIDC dans Omni** : dans `docker/oci-mgmt/docker-compose.yml`, mettre `OMNI_AUTH_SAML_ENABLED: "true"` (actuellement `"false"`).
2. **Configurer Authentik comme provider SAML dans Omni** : voir [Integrate Authentik with Omni](https://integrations.goauthentik.io/infrastructure/omni/).

### 4. Tester

Push sur `omni/**` ou déclencher manuellement le workflow. Le workflow :
1. Obtient un token OIDC depuis GitHub Actions
2. L'échange contre un access token Authentik (OAuth2 client_credentials)
3. Utilise ce token pour authentifier omnictl auprès d'Omni

**Références** :
- [Authentik OAuth2 Provider - Machine-to-machine](https://docs.goauthentik.io/add-secure-apps/providers/oauth2/#machine-to-machine-authentication)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

## Si l’UI renvoie HTTP 500

- **Logs Omni** : sur la VM, `docker logs oci-mgmt-omni` (ou `docker compose -f docker/oci-mgmt/docker-compose.yml logs omni`).
- **Base de données** : Omni utilise la DB `omni` sur PostgreSQL (créée par `docker/oci-mgmt/init-db/01-create-databases.sql`). Vérifier que le conteneur postgres est healthy et que `OMNI_DB_URL` dans le `.env` est correct.
- **Premier démarrage** : migrations Omni au premier run ; redémarrer une fois si besoin.

## Références

- [docs/omni-register-cluster.md](../docs/omni-register-cluster.md) — enregistrement DEV / CLOUD
- [docs/omni-automation.md](../docs/omni-automation.md) — flux CLOUD et DEV
- [docker/oci-mgmt/README.md](../docker/oci-mgmt/README.md) — déploiement de la stack (Omni, Authentik, Traefik)
