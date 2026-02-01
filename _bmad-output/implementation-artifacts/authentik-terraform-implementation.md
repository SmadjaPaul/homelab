# Détail d’implémentation : Authentik avec Terraform

**Date** : 2026-02-01  
**Contexte** : Homelab, design Authentik (session-travail-authentik.md §6).  
**Objectif** : Guide d’implémentation Terraform pour la configuration Authentik (applications, groupes, policies, service accounts), aligné avec les décisions prises et les ressources en ligne.

---

## 1. Références utilisées

| Ressource | Usage |
|-----------|--------|
| [Managing Authentik with Terraform (Tim Van Wassenhove)](https://timvw.be/2025/03/18/managing-authentik-with-terraform/) | Structure du projet, auth par variables d’environnement, patterns modulaires, data sources. |
| [Terraform Registry – goauthentik/authentik](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs) | Ressources et data sources officielles (applications, providers, groups, policies, users, tokens, flows, stages). |
| [Integrate with ArgoCD (Authentik)](https://integrations.goauthentik.io/infrastructure/argocd/) | Pattern app+provider OIDC, groupes (Admins / Viewers), redirect URIs, secret dans Helm/ESO. |
| [Authentik – Manage applications](https://docs.goauthentik.io/add-secure-apps/applications/manage_apps/) | Bindings Policy/Group/User, Application Entitlements, Launch URL `blank://blank` pour cacher une app. |
| [Authentik – Air-gapped](https://docs.goauthentik.io/install-config/air-gapped/) | Désactivation analytics / update check / error reporting ; avatars en `initials`. |
| [Authentik – User properties and attributes](https://docs.goauthentik.io/users-sources/user/user_ref/) | Attributs utilisateur/groupe pour granularité (quota, liste d’apps). |
| [Authentik – Service Accounts](https://docs.goauthentik.io/sys-mgmt/service-accounts/) | Comptes de service, tokens API. |
| [Manage Authentik Resources in Terraform (Christian Lempa)](https://christianlempa.de/videos/authentik-terraform/) | Provider config, proxy provider, application, data sources (flows). |
| [GoAuthentik de A à Y (une-tasse-de.cafe)](https://une-tasse-de.cafe/blog/goauthentik/#ajouter-des-utilisateurs) | Flows, stages, invitations, social login, policies (expression), accès par groupe. |

Design et décisions : `_bmad-output/planning-artifacts/session-travail-authentik.md` §6 ; epics/stories : `epics-and-stories-homelab.md` Epic 3.3.

---

## 2. Inspiration « GoAuthentik de A à Y » (une-tasse-de.cafe)

Article de référence : [GoAuthentik de A à Y](https://une-tasse-de.cafe/blog/goauthentik/) (Quentin JOLY). À s’en inspirer pour le setup homelab :

| Domaine | Référence article | Application pour nous |
|---------|-------------------|------------------------|
| **Flows & Stages** | Fonctionnement GoAuthentik (Stages, Flows, Policies). Authentication flow, Enrollment flow, Authorization flow (implicit vs explicit consent). | **Invitation-only** : enrollment accessible uniquement avec token d’invitation (Stage Invitation) ; self-registration désactivée. Voir `decision-invitation-only-et-acces-cloudflare.md`. Authorization : `default-provider-authorization-implicit-consent` pour les apps famille. |
| **Applications & providers** | Création app + provider (OAuth2/OIDC), redirect URIs, signing key, subject mode. Group (affichage) ≠ groupes d’accès. | Terraform : `authentik_application` + `authentik_provider_oauth2` ; bindings par groupe (family-validated, admin). |
| **Ajouter des utilisateurs** | Création manuelle ; Social Login (GitHub avec policy « organisation ») ; Invitations (lien, custom attributes, User Write Stage pour groupe automatique). | Self-registration activé ; validation manuelle (admin ajoute aux groupes dans l’UI). Invitations optionnel pour onboarding ciblé. |
| **Gérer les accès** | Par utilisateur, groupe ou policy. « Dans 99 % des cas je me contente de créer un groupe ayant accès à des sites et j’ajoute les utilisateurs à ces groupes. » | Même approche : groupes en Terraform ; qui est dans quel groupe = UI Authentik (Directory → Groups → Users). |
| **Policies (expression)** | Python, ex. heure de sauvegarde, pays IP, MFA, email domaine. | Utile plus tard : policy « MFA requis pour app X », ou « accès depuis réseau maison uniquement ». |
| **Notifications** | Event Matcher + Notification Transports (Webhook, Slack). | Webhook vers CI pour provisionnement ; optionnel notifications admin (nouveau user, erreurs). |
| **Reverse Proxy** | Agent Authentik (proxy) avec AUTHENTIK_HOST, AUTHENTIK_TOKEN ; ou middleware Traefik (Forward Auth). | Nous : oauth2-proxy (Story 3.3.2) ou proxy Authentik selon choix ; voir intégrations Authentik. |
| **Service accounts** | Directory → Users, type Service Account, groupe dédié (ex. pour LDAP). | Terraform : `authentik_user` (type=service_account) + `authentik_token` ; un groupe par usage si besoin. |

Session de travail (inspiration + suite BMad) : `session-travail-authentik.md` §7.

---

## 3. Ce que Terraform gère vs ce qu’il ne gère pas (décision clé)

**Problème** : Les utilisateurs humains sont créés à la volée (invitations uniquement ; self-registration désactivée). On ne peut pas modifier le code Terraform à chaque onboarding, ni lancer `terraform apply` à chaque nouvel utilisateur.

**Décision** : Séparer nettement ce qui est en Terraform et ce qui reste dans l’UI (ou l’API) Authentik.

| Dans Terraform | Pas dans Terraform (UI / API Authentik) |
|----------------|----------------------------------------|
| **Groupes** (admin, family-validated, family-app-*) | **Utilisateurs humains** (créés par inscription ou invitation) |
| **Applications + providers** (OAuth2, Proxy, etc.) | **Qui est dans quel groupe** : affectation user → groupe dans l’UI Authentik (ou via API/CI) |
| **Policies et bindings** (groupes ↔ applications) | Activation / désactivation d’un user, validation manuelle |
| **Service accounts** (ci-github, argocd, backup, n8n) + leurs tokens | — |

En résumé :

- **Terraform** définit la **structure** : quels groupes existent, quelles apps, quels accès par groupe, quels comptes de service. C’est la « grille » des droits.
- **Authentik UI** (Directory → Users, Groups → membres) : tu vois qui est dans quel groupe et tu ajoutes/retires des utilisateurs aux groupes après validation. Pas besoin de toucher au Terraform pour ça.
- **Granularité** : elle est gérée **par groupe** dans Terraform (ex. `family-app-nextcloud`, `family-app-navidrome`). L’affectation granulaire « Paul a Nextcloud + 50 Go, Marie a Navidrome seulement » se fait en mettant Paul et Marie dans les bons groupes depuis l’UI.

Références utiles pour le flux utilisateurs et les groupes : [Christian Lempa – Authentik Terraform](https://christianlempa.de/videos/authentik-terraform/) (provider, apps), [GoAuthentik de A à Y – Ajouter des utilisateurs](https://une-tasse-de.cafe/blog/goauthentik/#ajouter-des-utilisateurs) (invitations, social login, **gérer les accès aux applications** par groupe).

---

## 4. Authentification du provider Terraform

**Ne pas mettre les identifiants en dur dans le code.** Utiliser des variables d’environnement (ou un `.env` non versionné) :

```bash
# .env (ne pas commiter)
AUTHENTIK_URL="https://authentik.apps.example.com/"
AUTHENTIK_TOKEN="<token_api_ou_app_password>"
```

Le provider [goauthentik/authentik](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs) accepte ces variables. Avant chaque run :

```bash
source .env
terraform plan
terraform apply
```

Le token doit être un **API Token** (ou App password) d’un utilisateur Authentik avec droits admin. Pour la CI : utiliser un **service account** créé par Terraform (bootstrap manuel du premier token), puis stocker le token dans un secret manager (Bitwarden/ESO) et l’injecter en CI.

---

## 5. Structure Terraform recommandée (modulaire)

Organisation proposée (inspirée de [Tim Van Wassenhove](https://timvw.be/2025/03/18/managing-authentik-with-terraform/)) :

```
terraform/authentik/
├── provider.tf          # required_providers + provider "authentik"
├── variables.tf         # url, token (sensitive) optionnels si on préfère env
├── data.tf             # data sources (flows, certificate)
├── groups.tf           # authentik_group : admin, family-validated, family-app-*
├── policies.tf         # authentik_policy_* + authentik_policy_binding
├── applications.tf     # authentik_application + provider OAuth2 par app
├── applications_admin.tf  # apps admin (ArgoCD, Grafana, Omni, etc.) + bindings admin
├── service_accounts.tf # authentik_user (type=service_account) + authentik_token
├── outputs.tf          # client_id, client_secret (sensitive) pour ESO/ArgoCD
├── terraform.tfvars.example
└── README.md           # prérequis, ordre apply, gestion des secrets
```

Séparation **applications famille** vs **applications admin** pour clarifier les bindings (famille → groupes famille ; admin → groupe `admin` uniquement). **Aucun `authentik_user` pour les utilisateurs humains** : ils sont gérés dans l’UI ; seuls les service accounts sont définis en Terraform.

---

## 6. Provider et data sources

### 6.1 Bloc provider

```hcl
terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2024.12"  # ou dernière stable
    }
  }
}

provider "authentik" {
  # URL et token via AUTHENTIK_URL et AUTHENTIK_TOKEN
}
```

### 6.2 Data sources (ressources existantes Authentik)

Les flows et clés par défaut sont créés à l’install Authentik. On les référence sans les gérer :

```hcl
# Flow d’autorisation OIDC par défaut (consent)
data "authentik_flow" "default_authorization_flow" {
  slug = "default-provider-authorization-implicit-consent"
}

# Clé de signature (self-signed ou la tienne)
data "authentik_certificate_key_pair" "default" {
  name = "authentik Self-signed Certificate"
}
```

Référence : [Terraform Registry – Data Sources](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs). Flows par défaut : [Default flows](https://docs.goauthentik.io/add-secure-apps/flows-stages/flow/examples/default_flows).

---

## 7. Groupes et policies

### 7.1 Groupes (session §6.1, §6.2)

Créer au minimum :

- `admin` : accès aux apps d’administration (Authentik Admin, Omni, ArgoCD, Grafana, etc.).
- `family-validated` : utilisateurs validés ; nécessaire (avec d’autres groupes ou non) pour voir les apps « famille ».
- Optionnel : `family-app-nextcloud`, `family-app-navidrome`, etc., si tu veux une granularité par app.

```hcl
resource "authentik_group" "admin" {
  name         = "admin"
  is_superuser = true  # si tu veux que ce groupe ait tous les droits Authentik
}

resource "authentik_group" "family_validated" {
  name = "family-validated"
}

# Optionnel : un groupe par app pour affectation granulaire
resource "authentik_group" "family_app_nextcloud" {
  name = "family-app-nextcloud"
}
```

### 7.2 Policies « groupe » et bindings

Pour restreindre l’accès à une **application** à un groupe, on utilise en général :

1. Une **policy** qui exprime « user membre du groupe X » (souvent une **Group policy** ou **Expression policy**).
2. Un **binding** entre cette policy et l’application.

Dans le provider, cela peut correspondre à :

- `authentik_policy_group` (ou équivalent) pour « accès si user dans groupe Y ».
- `authentik_policy_binding` (ou binding au niveau application) pour lier la policy à l’application.

Consulter le [Terraform Registry – Policies](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs) pour les noms exacts (`authentik_policy_group`, `authentik_application_*`). En UI Authentik : *Applications > [App] > Policy/Group/User Bindings*.

Exemple conceptuel (à adapter aux noms de ressources du registry) :

```hcl
# Policy : accès si membre du groupe family-validated
resource "authentik_policy_group" "family_validated" {
  name  = "policy-family-validated"
  group = authentik_group.family_validated.id
}

# Lier cette policy à l’application Nextcloud (id de l’application)
# Ressource type authentik_policy_binding ou équivalent selon le provider
```

**Apps admin** : même principe avec le groupe `admin` uniquement. Pour qu’elles n’apparaissent pas dans le portail « famille », utiliser **Launch URL** = `blank://blank` ([Manage applications](https://docs.goauthentik.io/add-secure-apps/applications/manage_apps/)).

---

## 8. Applications et providers OAuth2

### 8.1 Pattern général (app + provider OIDC)

Chaque app « famille » ou « admin » nécessite :

1. Un **provider** OAuth2/OIDC (client_id, client_secret, redirect URIs, signing key, authorization flow).
2. Une **application** Authentik (nom, slug, lien vers le provider).
3. Des **bindings** (policy/groupe) pour qui peut voir et accéder à l’app.

Référence : [Manage applications](https://docs.goauthentik.io/add-secure-apps/applications/manage_apps/), [Integrate with ArgoCD](https://integrations.goauthentik.io/infrastructure/argocd/).

Exemple **conceptuel** (noms de ressources à vérifier dans le [Registry](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)) :

```hcl
# Provider OAuth2 pour Nextcloud (exemple)
resource "authentik_provider_oauth2" "nextcloud" {
  name               = "nextcloud"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  client_id          = "nextcloud"
  client_secret      = var.nextcloud_client_secret  # variable sensitive, fournie par ESO ou tfvars
  redirect_uris       = ["https://nextcloud.example.com/apps/oauth2/redirect"]
  signing_key        = data.authentik_certificate_key_pair.default.id
}

# Application Authentik
resource "authentik_application" "nextcloud" {
  name              = "Nextcloud"
  slug              = "nextcloud"
  protocol_provider = authentik_provider_oauth2.nextcloud.id
  launch_url        = "https://nextcloud.example.com"
  # Policy engine mode : ANY = membre d’au moins un groupe lié ; ALL = tous les groupes liés
}
```

Les **client_secret** ne doivent pas être en clair dans le repo : utiliser des variables Terraform (sensitive) alimentées par ESO/Bitwarden ou par un pipeline CI.

### 8.2 ArgoCD (exemple app admin)

Pattern tiré de [Integrate with ArgoCD](https://integrations.goauthentik.io/infrastructure/argocd/) :

- **Redirect URIs** : `https://argocd.company/api/dex/callback` et `https://localhost:8085/auth/callback`.
- **Groupes** : `ArgoCD Admins`, `ArgoCD Viewers` (ou réutiliser `admin` + un groupe readonly si tu préfères).
- **ArgoCD** : secret `dex.authentik.clientSecret`, ConfigMap `argocd-cm` (dex.config avec issuer, clientID, clientSecret, scopes), `argocd-rbac-cm` (policy.csv pour mapper les groupes Authentik aux rôles ArgoCD).

En Terraform Authentik : créer l’application + provider OAuth2 avec ces redirect URIs, créer les groupes (ex. `ArgoCD Admins`), lier l’app au groupe `admin` (ou `ArgoCD Admins`). Exporter le **client_secret** en output sensible et l’injecter dans ArgoCD via Helm/ESO.

### 8.3 Liste des apps (catalogue)

Pour savoir « quelles applications sont proposées » (pour affectation granulaire et provisionnement) :

- **Option A** : Liste versionnée en YAML/JSON dans le repo (ex. `catalogue-apps-famille.yaml`) : nom, slug, type (nextcloud, navidrome, …), quotas par profil.
- **Option B** : Dériver la liste des apps depuis les ressources Terraform (`authentik_application` pour les apps famille) et l’utiliser en CI pour le provisionnement.

Les deux sont compatibles avec le design session §6.

---

## 9. Service accounts (session §6.4)

### 9.1 Utilisateurs de type service account

Créer un user par usage : `ci-github`, `argocd`, `backup`, `n8n`. Référence : [Authentik Service Accounts](https://docs.goauthentik.io/sys-mgmt/service-accounts/), [authentik_user](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/user), [authentik_token](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/token).

```hcl
resource "authentik_user" "ci_github" {
  username     = "ci-github"
  name         = "CI GitHub"
  type         = "service_account"
  is_active    = true
  # groups = []  # ajouter si besoin de permissions spécifiques
}
```

### 9.2 Tokens API

Un token par service account pour les appels API (CI, scripts) :

```hcl
resource "authentik_token" "ci_github" {
  identifier   = "ci-github-api"
  user         = authentik_user.ci_github.id
  description  = "API token for GitHub Actions / CI"
  intent       = "api"
  expiring     = true
  retrieve_key = true  # pour afficher le token une fois (à stocker dans ESO)
}
```

**Important** : `retrieve_key = true` permet de récupérer le token en output une seule fois. Le stocker immédiatement dans Bitwarden/ESO et ne jamais le commiter. En CI : lire le secret depuis ESO et exporter `AUTHENTIK_TOKEN` (et `AUTHENTIK_URL`).

Documenter la **rotation** : recréer le token (taint ou replace), mettre à jour le secret dans ESO, redéployer les jobs qui l’utilisent.

---

## 10. Isolation des données entre utilisateurs

- **Authentik** : chaque utilisateur n’a accès qu’aux applications pour lesquelles il a un binding (groupe/policy). Pas de groupe unique « famille » qui donne tout à tout le monde si tu veux du granulaire : utiliser des groupes par app ou des Application Entitlements ([Manage applications](https://docs.goauthentik.io/add-secure-apps/applications/manage_apps/)).
- **Provisionnement** : la CI crée **un compte par utilisateur** dans chaque app (Nextcloud, Navidrome, etc.), avec quota/options dérivés des attributs Authentik (ou du catalogue). Aucun compte partagé pour les données personnelles.
- **Apps** : configurer chaque app pour qu’elle utilise l’utilisateur OIDC (ou le compte local dédié) et n’affiche que les données de ce compte.

Aucune ressource Terraform supplémentaire spécifique : c’est le bon usage des groupes, policies et du flux de provisionnement qui garantit l’isolation.

---

## 11. Webhook / Event Transport (provisionnement)

La décision session §6.3 : webhook Authentik (event `user_write` ou changement de groupe) → CI crée les comptes dans les apps.

Dans Authentik : **System → Event Transports** : créer un transport de type **Webhook**, URL = endpoint CI (ex. GitHub Actions workflow ou service interne). Sélectionner les événements (ex. `user_write`, ou custom si le provider expose un event sur changement de groupe).

Le provider Terraform peut exposer une ressource pour les **Event Transports** : vérifier dans le [Registry](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs). Si absent, configurer le webhook à la main une fois (ou via API dans un script bootstrap) et le documenter dans le runbook.

---

## 12. Air-gapped / renforcement (optionnel)

Pour limiter les connexions sortantes ([Air-gapped](https://docs.goauthentik.io/install-config/air-gapped/)) :

- Variables d’environnement Authentik (Docker Compose ou Helm) :  
  `AUTHENTIK_DISABLE_STARTUP_ANALYTICS=true`, `AUTHENTIK_DISABLE_UPDATE_CHECK=true`, `AUTHENTIK_ERROR_REPORTING__ENABLED=false`.
- System settings : **Avatars** → `initials` (pas Gravatar).

Cela relève du déploiement Authentik (Story 3.3.1), pas du Terraform de configuration.

---

## 13. Ordre d’exécution et bootstrap

1. **Déployer Authentik** (Docker Compose / Helm) et créer un premier utilisateur admin (ou utiliser le bootstrap).
2. **Créer un token API** pour cet admin (UI Authentik), le mettre dans `.env` (ou ESO) pour Terraform.
3. **terraform apply** dans `terraform/authentik/` : groupes, policies, applications, providers, service accounts, tokens.
4. **Récupérer les outputs** (client_secret des apps, token des service accounts) et les stocker dans ESO/Bitwarden ; ne plus jamais les afficher en clair.
5. **Configurer ArgoCD** (et les autres apps) avec les client_id / client_secret exportés (voir [ArgoCD integration](https://integrations.goauthentik.io/infrastructure/argocd/)).
6. **Configurer le webhook** (Event Transport) vers la CI pour le provisionnement.

---

## 14. Checklist d’implémentation (épics 3.3)

| Story | Élément Terraform / action |
|-------|----------------------------|
| 3.3.1 Deploy Authentik | Hors Terraform (Compose/Helm). Après déploiement : créer groupes `admin`, `family-validated` (Terraform ou UI une fois). |
| 3.3.2 oauth2-proxy | Config oauth2-proxy (client_id/secret depuis Terraform outputs). |
| 3.3.3 Applications Family vs Admin | `authentik_application` + `authentik_provider_oauth2` par app ; bindings vers `family-validated` (et groupes par app si besoin) ou `admin` ; Launch URL `blank://blank` pour apps admin. |
| 3.3.4 Webhook & CI | Event Transport webhook (Terraform si dispo, sinon manuel/API) ; CI provisionnement (comptes par user). |
| 3.3.5 Service accounts | `authentik_user` (type=service_account) + `authentik_token` ; secrets dans ESO. |

---

## 15. Ressources Terraform Registry à utiliser (résumé)

- **Data** : `authentik_flow`, `authentik_certificate_key_pair`
- **Identity** : `authentik_group`, `authentik_user`, `authentik_token`
- **Applications** : `authentik_application`, `authentik_provider_oauth2` (ou nom équivalent)
- **Authorization** : `authentik_policy_*`, `authentik_policy_binding` (ou équivalent pour lier policy à application)
- **Flows/Stages** : optionnel si tu personnalises l’enrollment (sinon utiliser les flows par défaut)

Toujours vérifier les noms exacts et arguments sur : [registry.terraform.io/providers/goauthentik/authentik/latest/docs](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs).

---

*Document à mettre à jour au fur et à mesure de l’implémentation (noms de ressources exacts, exemples testés).*
