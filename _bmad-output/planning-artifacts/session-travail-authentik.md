# Session de travail : design Authentik (identité & accès)

**Date** : 2026-01-31  
**Objectif** : Affiner avec l’agent PM (ou en atelier) ce qu’on souhaite faire avec Authentik : setup facile pour les utilisateurs finaux, sécurisé (validation manuelle avant accès aux apps), pas d’exposition des apps d’administration, et usage des service accounts pour les connexions entre services.

**IdP retenu** : **Authentik** (voir `identity-stack-besoins-et-solutions.md`).

---

## 1. Contexte et décisions déjà prises

- **Authentik** : IdP (SSO OIDC/SAML), intégration Omni ([Integrate with Omni](https://integrations.goauthentik.io/infrastructure/omni/)), webhooks (Notification Transports), service accounts (Terraform goauthentik/authentik).
- **Souhaits** :
  - Setup **facile** pour les utilisateurs finaux.
  - **Sécurisé** : pas d’accès direct aux applications à l’inscription ; **validation manuelle** (par l’admin) avant d’ajouter l’utilisateur dans la CI / aux apps.
  - **Ne pas exposer** les applications d’administration (Grafana, ArgoCD, Omni, Authentik admin, etc.) aux utilisateurs finaux.
  - **Service accounts** pour gérer les connexions entre les différents services (machine-to-machine).

---

## 2. Thèmes pour la session (à trancher avec l’agent PM)

### 2.1 Flux utilisateur final (inscription → accès aux apps)

| Question | Options / à définir |
|----------|----------------------|
| **Inscription** | Self-registration Authentik activé ? (oui recommandé pour « setup facile ».) |
| **Après inscription** | L’utilisateur a-t-il accès à une app tout de suite ? **Non** : il n’est dans aucun groupe donnant accès aux apps tant qu’il n’est pas validé. |
| **Validation** | Qui valide ? Admin (toi). Où ? Dans Authentik (activer user / ajouter à un groupe « validé ») **et/ou** dans la CI (ex. job manuel « valider user X » qui ajoute l’user aux groupes / déclenche le provisionnement). |
| **Après validation** | L’admin ajoute l’utilisateur à un groupe (ex. `family-validated` ou `family-app-nextcloud`). Policy Authentik : seuls les users de ce groupe accèdent aux apps. La CI (déclenchée par webhook ou manuellement) crée les comptes dans Nextcloud, Navidrome, etc. |
| **Résumé du flux** | 1) User s’inscrit (Authentik). 2) User **n’a pas** accès aux apps (pas dans les groupes « app »). 3) Admin valide (Authentik + éventuellement CI). 4) Admin ajoute user au(x) groupe(s) → policies Authentik donnent accès. 5) (Optionnel) Webhook Authentik → CI crée les comptes dans les apps. |

**À valider** : Étapes exactes (Authentik seul vs CI manuelle vs webhook), nom des groupes, qui fait quoi (admin uniquement vs délégation).

---

### 2.2 Applications exposées vs applications d’administration (non exposées)

| Catégorie | Exemples | Exposition | Comment |
|-----------|----------|------------|--------|
| **Apps famille / utilisateurs finaux** | Nextcloud, Navidrome, Vaultwarden, Baïkal, Mealie, Glance, etc. | Exposées via Cloudflare Tunnel (ou équivalent), protégées par Authentik (oauth2-proxy ou proxy Authentik). | Visibles dans « My applications » Authentik **uniquement** pour les users ayant les bons groupes. |
| **Apps d’administration** | Authentik Admin, Omni UI, ArgoCD, Grafana (admin), Prometheus, etc. | **Non exposées** aux utilisateurs finaux. | Pas de lien dans le portail Authentik pour les groupes « famille ». Accès réservé aux admins (groupe `admin` ou équivalent) ; URLs non publiées ou protégées par policy stricte (IP, groupe). |

**À valider** : Liste précise des apps « famille » vs « admin », et comment on restreint l’accès (groupes Authentik, policies, pas de binding pour les apps admin dans le portail famille).

---

### 2.3 Rôle de la CI dans la validation et le provisionnement

| Question | Options / à définir |
|----------|----------------------|
| **Validation = manuelle dans la CI ?** | Tu veux « valider manuellement dans la CI » : ça peut signifier (a) un job CI (ex. GitHub Actions) déclenché **manuellement** avec le username/email → le job ajoute l’user à un groupe Authentik (via API) et/ou déclenche le provisionnement ; (b) ou tu valides dans l’UI Authentik (activer user, ajouter au groupe) et la CI ne fait que le provisionnement (webhook sur changement de groupe). |
| **Provisionnement** | Une fois l’user validé (et ajouté à des groupes « app »), la CI crée les comptes dans Nextcloud, Navidrome, etc. (API ou scripts). Déclenchement : webhook Authentik (event `user_write` ou groupe) ou job CI manuel. |
| **Sécurité** | Les utilisateurs non validés ne sont dans **aucun** groupe donnant accès aux apps ; les policies Authentik refusent l’accès. |

**À valider** : Workflow exact (validation 100 % dans Authentik vs validation via job CI manuel), et qui a le droit de lancer le job CI « valider user ».

---

### 2.4 Service accounts (connexions entre services)

| Question | Options / à définir |
|----------|----------------------|
| **Usage** | Service accounts Authentik pour : CI (appels API Authentik, déploiements), ArgoCD (si besoin auth), scripts de backup, intégrations entre services (ex. n8n → API X), etc. |
| **Granularité** | Un service account par usage (ex. `ci-github`, `argocd`, `n8n`, `backup`) avec droits minimaux. |
| **IaC** | Définir les service accounts (et leurs tokens/intent) en **Terraform** (provider goauthentik/authentik) pour `terraform apply` reproductible. |
| **Sécurité** | Tokens stockés dans un secret manager (Bitwarden / Vault), jamais en clair dans le repo. |

**À valider** : Liste des service accounts à créer (nom, rôle), où sont stockés les secrets, et qui peut modifier le Terraform (admin uniquement).

---

### 2.5 Setup « facile » pour les utilisateurs finaux

| Question | Options / à définir |
|----------|----------------------|
| **Première connexion** | Redirection vers Authentik, inscription (email, mot de passe), puis message « Votre compte est en attente de validation » (pas d’accès aux apps). |
| **Après validation** | Email (optionnel) ou notification « Vous avez accès à … » ; l’user revient sur le portail Authentik et voit les apps autorisées (My applications). |
| **Documentation** | Une page « Comment s’inscrire / demander un accès » (lien vers Authentik, explication du délai de validation). |
| **Catalogue d’apps** | (Optionnel) Page ou flow « Choisis tes apps » après validation : l’admin ou un flow ajoute l’user aux groupes correspondants ; la CI provisionne. À trancher dans la session. |

**À valider** : Message post-inscription, notification après validation, besoin ou non d’un catalogue self-service « choix d’apps ».

---

## 3. Livrables attendus de la session

- **Flux utilisateur** : schéma ou liste d’étapes (inscription → attente → validation → accès aux apps).
- **Liste apps famille vs admin** : quelles apps sont exposées aux utilisateurs finaux, lesquelles restent cachées/réservées admin.
- **Rôle de la CI** : validation uniquement dans Authentik vs job CI manuel « valider user » ; déclenchement du provisionnement (webhook vs manuel).
- **Liste des service accounts** : noms, usages, gestion des secrets.
- **Mises à jour des specs** : PRD et architecture reflètent ces choix (Authentik, validation manuelle, pas d’exposition admin, service accounts).

---

## 4. Comment utiliser ce document avec l’agent PM (BMad)

- **Commande suggérée** : Ouvrir une session avec l’agent PM (workflow BMad *prd ou *create-epics ou brainstorming) et lui donner ce document comme entrée : « On a choisi Authentik. Voici le document de session de travail (session-travail-authentik.md) : on veut affiner le flux utilisateur (validation manuelle, pas d’accès direct après inscription), les apps exposées vs admin, le rôle de la CI, et les service accounts. Peux-tu proposer des décisions claires et les refléter dans le PRD / les epics ? »
- **Entrées** : `session-travail-authentik.md`, `architecture-proxmox-omni.md` (v6 avec Authentik), `identity-stack-besoins-et-solutions.md`.
- **Sorties attendues** : Décisions formalisées (flux, listes, rôles CI), mises à jour PRD / epics si besoin, et éventuellement stories « Authentik : validation manuelle », « Authentik : policies apps admin vs famille », « Service accounts Terraform ».

---

## 5. Références

- [Authentik – Integrate with Omni](https://integrations.goauthentik.io/infrastructure/omni/)
- [Authentik – Events & Notification Transports](https://docs.goauthentik.io/sys-mgmt/events/event-actions/)
- [Authentik – Service Accounts](https://docs.goauthentik.io/sys-mgmt/service-accounts/)
- [Authentik – Policies / Groups](https://docs.goauthentik.io/)
- [Terraform provider Authentik](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)

---

## 6. Décisions prises (session PM — 2026-02-01)

Les décisions ci-dessous formalisent les choix pour le design Authentik. Elles sont reflétées dans le PRD v2.0 et l’architecture v6.0.

### 6.1 Flux utilisateur final

| Décision | Choix |
|----------|--------|
| **Onboarding** | **Invitation uniquement**. Self-registration **désactivée**. Aucun compte créé sans lien d’invitation (token) envoyé par l’admin. Flux d’enrollment accessible uniquement avec un token d’invitation (Stage Invitation). Voir `decision-invitation-only-et-acces-cloudflare.md`. |
| **Création d’invitations** | **UI Authentik** (Directory → Invitations) ou **API** (`POST /api/v3/stages/invitation/invitations/`). Le provider Terraform n’a pas de ressource `authentik_invitation` ; les invitations restent hors Terraform (script/CI ou UI). |
| **Accès après enrollment (invitation)** | Selon le flow : l’utilisateur peut être ajouté à un ou plusieurs groupes dès l’enrollment (User Write Stage) ; sinon l’admin ajoute aux groupes après coup. Aucun accès aux apps tant que l’user n’est pas dans les groupes autorisés. |
| **Validation** | **Manuelle par l’admin dans Authentik**. L’admin envoie un lien d’invitation ; après enrollment, l’admin ajoute éventuellement l’utilisateur à d’autres groupe(s) (ex. `family-validated`, `family-app-nextcloud`). Aucun accès aux apps avant d’être dans les bons groupes. |
| **Option CI pour validation** | **Optionnel**. Un job CI manuel peut appeler l’API Authentik pour ajouter l’user à un groupe et/ou déclencher le provisionnement. La décision d’inviter reste initiée par l’admin. |
| **Après validation (groupes)** | L’utilisateur est dans un ou plusieurs groupes (ex. `family-validated`, `family-app-nextcloud`). Les policies Authentik donnent accès aux apps liées. Le portail « My applications » affiche uniquement les apps autorisées. |
| **Provisionnement dans les apps** | **Webhook Authentik** (recommandé) : event `user_write` ou changement de groupe → Notification Transport appelle une URL (CI) → la CI crée les comptes dans Nextcloud, Navidrome, Mealie, etc. Alternative : job CI manuel après validation. |

**Résumé du flux** : 1) Admin crée une invitation (UI ou API) et envoie le lien à l’utilisateur. 2) Utilisateur clique sur le lien, complète l’enrollment (mot de passe, etc.). 3) Admin ajoute aux groupes si besoin. 4) Accès aux apps selon les groupes. 5) Webhook → CI provisionne les comptes dans les apps (optionnel mais recommandé).

**Groupes Authentik (nominaux)** : `admin` (accès admin), `family-validated` (utilisateur validé), `family-app-nextcloud`, `family-app-navidrome`, etc. selon besoin ; ou un seul groupe `family-validated` avec policy par application. À affiner à l’implémentation.

---

### 6.2 Applications exposées vs administration

| Catégorie | Liste | Exposition | Restriction |
|-----------|------|------------|-------------|
| **Apps famille (utilisateurs finaux)** | Nextcloud, Vaultwarden, Baïkal, Navidrome, Mealie, Glance, Immich, n8n (optionnel) | Exposées via Cloudflare Tunnel ; protégées par Authentik (oauth2-proxy ou proxy Authentik). | Visibles dans « My applications » **uniquement** pour les utilisateurs ayant les groupes autorisés (ex. `family-validated` + groupe par app si utilisé). |
| **Apps d’administration** | Authentik Admin, Omni UI, ArgoCD, Grafana (admin), Prometheus, Alertmanager, ntfy (admin) | **Non exposées** aux utilisateurs finaux. Pas de lien dans le portail Authentik pour les groupes « famille ». | Accès réservé au groupe `admin`. URLs non publiées sur le portail famille ; accès direct (URL connue) + auth Authentik avec policy « groupe admin » ou accès restreint (IP/VPN). |

**Implémentation** : Bindings d’applications Authentik : les apps « famille » sont liées aux groupes famille ; les apps « admin » sont liées au groupe `admin` uniquement. Les utilisateurs famille ne voient pas les apps admin dans le portail.

---

### 6.3 Rôle de la CI

| Décision | Choix |
|----------|--------|
| **Validation** | **Dans Authentik** (UI admin : activer user, ajouter aux groupes). Pas de validation « uniquement dans la CI » : la source de vérité pour « validé » est Authentik. |
| **Job CI « valider user »** | **Optionnel**. Si utilisé : job déclenché manuellement (`workflow_dispatch`) avec paramètres (username/email) ; le job appelle l’API Authentik pour ajouter l’user à un groupe et peut ensuite lancer le provisionnement. Seuls les mainteneurs du repo (admin) peuvent lancer ce job. |
| **Provisionnement** | **Webhook Authentik** (event `user_write` ou changement de groupe) → POST vers une URL CI → la CI crée les comptes dans Nextcloud, Navidrome, Mealie, etc. Alternative : job CI manuel après validation. |
| **Sécurité** | Les utilisateurs non validés (pas dans les groupes « app ») n’ont aucun accès aux applications ; les policies Authentik refusent l’accès. |

---

### 6.4 Service accounts

| Décision | Choix |
|----------|--------|
| **Usage** | Service accounts Authentik pour : **CI** (appels API Authentik, déploiements), **ArgoCD** (auth si nécessaire), **scripts de backup**, **n8n** (intégrations API). Un service account par usage, droits minimaux. |
| **Liste nominale** | `ci-github` (CI/CD, API Authentik, provisionnement), `argocd` (ArgoCD si auth IdP), `backup` (scripts backup), `n8n` (n8n → API externes). Liste extensible à l’implémentation. |
| **IaC** | Définition en **Terraform** (provider goauthentik/authentik) : `authentik_user` avec `type = "service_account"`, groupes/permissions. `terraform apply` pour créer/mettre à jour. |
| **Secrets** | Tokens (API Token, App password) stockés dans un **secret manager** (Bitwarden / ESO) ; jamais en clair dans le repo. Qui peut modifier le Terraform : **admin uniquement** (contrôle d’accès Git). |

---

### 6.5 Setup pour les utilisateurs finaux

| Décision | Choix |
|----------|--------|
| **Première connexion** | L’utilisateur reçoit un **lien d’invitation** (email, etc.) ; en cliquant, il est redirigé vers le flow d’enrollment Authentik (mot de passe, etc.). Pas de page d’inscription publique : tout passe par l’invitation. |
| **Après enrollment / validation** | (Optionnel) Notification ou email « Vous avez accès à … » ; l’utilisateur revient sur le portail Authentik et voit « My applications » avec les apps autorisées. |
| **Documentation** | Une page « Comment obtenir un accès » : explication que l’accès se fait sur invitation (l’admin envoie un lien) ; pas d’inscription ouverte. |
| **Catalogue « choix d’apps »** | **Optionnel (phase ultérieure)**. Pour le MVP : l’admin assigne les groupes (et donc les apps) à chaque utilisateur. Un flow « choisir ses apps » (catalogue self-service) peut être ajouté plus tard. |

---

### 6.6 Synthèse des livrables

- **Flux** : Invitation (admin envoie le lien) → enrollment (utilisateur complète le flow) → ajout aux groupes si besoin → accès aux apps (groupes) → webhook → CI provisionne (optionnel).
- **Apps famille** : Nextcloud, Vaultwarden, Baïkal, Navidrome, Mealie, Glance, Immich, n8n. **Apps admin** : Authentik Admin, Omni, ArgoCD, Grafana, Prometheus, Alertmanager, ntfy (admin).
- **CI** : Validation dans Authentik ; provisionnement par webhook (recommandé) ou job manuel ; job CI « valider user » optionnel.
- **Service accounts** : ci-github, argocd, backup, n8n ; Terraform ; secrets dans Bitwarden/ESO.
- **PRD / Architecture** : Mis à jour pour refléter ces décisions (voir PRD § Identity Design, architecture § 2.8).

---

## 7. Inspiration « GoAuthentik de A à Y » (une-tasse-de.cafe) et suite BMad

### 7.1 Inspiration setup une-tasse-de.cafe

Article de référence : [GoAuthentik de A à Y](https://une-tasse-de.cafe/blog/goauthentik/) (Quentin JOLY, une-tasse-de.cafe). Points à s’en inspirer pour le homelab :

| Thème | Ce qu’on en retient pour notre setup |
|-------|--------------------------------------|
| **Flows & Stages** | Comprendre les flows (Authentication, Enrollment, Authorization), les stages (Identification, Password, User Write, Invitation). Notre enrollment : **invitation-only** (Stage Invitation) ; pas de self-registration. User Write Stage optionnel pour ajouter à un groupe dès l’enrollment. |
| **Ajouter des utilisateurs** | **Invitations uniquement** (lien unique, pré-remplissage, User Write Stage optionnel pour groupe à l’enrollment). Self-registration désactivée. Création manuelle ou Social Login réservées à l’admin si besoin. |
| **Gérer les accès aux applications** | Accès par **utilisateur, groupe ou policy**. On privilégie **groupes** : créer un groupe par type d’accès, ajouter les utilisateurs aux groupes dans l’UI (Directory → Groups → Users). Pas d’utilisateurs humains dans Terraform. |
| **Policies (expression)** | Policies Python pour conditions avancées (ex. heure, IP, MFA, organisation GitHub). Utile plus tard pour renforcer la sécurité (ex. MFA obligatoire pour une app). |
| **Notifications** | Event Matcher + Notification Transports (Webhook, Slack, email). Pour nous : webhook vers CI pour provisionnement ; optionnel notifications admin (nouvel user, erreurs). |
| **Reverse Proxy** | Agent Authentik (proxy) ou middleware (Traefik). Nous : oauth2-proxy ou proxy Authentik selon les stories ; voir Epic 3.3 et 3.4. |
| **LDAP, Recovery, MFA** | Article couvre LDAP, réinitialisation mot de passe, MFA à l’accès à une app. À considérer en phase ultérieure si besoin. |

Détail d’implémentation (Terraform vs UI, groupes, service accounts) : `_bmad-output/implementation-artifacts/authentik-terraform-implementation.md`.

### 7.2 Suite BMad : mises à jour à faire dans le framework

Pour intégrer ces décisions et l’inspiration une-tasse-de.cafe dans le framework BMad :

| Étape | Artifact | Action |
|-------|----------|--------|
| 1 | **session-travail-authentik.md** | ✅ Décisions §6 déjà prises ; §7 (inspiration + suite BMad) ajouté. |
| 2 | **authentik-terraform-implementation.md** | ✅ Document à jour (Terraform vs UI, groupes, service accounts). Ajouter section « Inspiration une-tasse-de.cafe » détaillée (voir implementation-artifacts). |
| 3 | **epics-and-stories-homelab.md** | Ajouter dans Epic 3.3 (ou stories 3.3.x) : référence au doc d’implémentation, précision « gestion par groupe dans Terraform ; utilisateurs et appartenance aux groupes dans l’UI Authentik ». Optionnel : critères d’acceptation inspirés de une-tasse-de.cafe (flows, invitations, accès par groupe). |
| 4 | **PRD / Architecture** | Vérifier que le PRD et l’architecture (Identity Design, §2.8) reflètent : validation manuelle, groupes, Terraform (structure + service accounts), UI pour les users. Compléter si besoin. |
| 5 | **Sprint / implémentation** | Utiliser `*dev-story` pour les stories 3.3.x en s’appuyant sur `authentik-terraform-implementation.md` et sur l’article une-tasse-de.cafe pour les réglages UI (flows, groupes, notifications). |

Ordre suggéré : 3 → 4 → 5 (mise à jour epics/stories et PRD/architecture, puis implémentation des stories).
