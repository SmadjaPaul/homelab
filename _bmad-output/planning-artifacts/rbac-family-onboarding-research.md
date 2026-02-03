# RBAC & Onboarding familial : auto-inscription + catalogue d’apps + provisionnement

**Date** : 2026-01-31  
**Contexte** : Permettre à la famille de s’auto-inscrire, choisir les applications (hors admin/monitoring), puis déclencher une CI qui crée les comptes dans chaque service avec les bonnes ressources.  
**Choix homelab** : Authentik (IdP retenu).

---

## 1. Objectif

- **Self-registration** : premier accès = inscription (pas de compte créé à la main).
- **Catalogue restreint** : l’utilisateur choisit les apps qu’il veut parmi une liste excluant l’admin et le monitoring (Grafana, ArgoCD, Omni, etc.).
- **Provisionnement automatisé** : une CI crée les comptes dans chaque service sélectionné (Navidrome, Nextcloud, Mealie, etc.) avec quotas/ressources adaptés.

---

## 2. Résultat de la recherche : existe-t-il une solution clé en main ?

**Réponse courte : non.** Aucun produit open source trouvé qui fait exactement :

> « Self-register → choisir des apps dans un catalogue (excluant admin/monitoring) → CI crée les comptes dans chaque app avec les bonnes ressources ».

Les briques existent séparément ; il faut les composer.

---

## 3. Briques existantes (open source)

### 3.1 Identity & self-registration

| Solution | Self-registration | Groupes / rôles | Déclencher une action après inscription |
|----------|-------------------|------------------|----------------------------------------|
| **Keycloak** | Oui (realm setting) | Oui (groups, roles) | Event Listener SPI → webhook ou API ; ou plugins [keycloak-webhook](https://github.com/vymalo/keycloak-webhook), [keycloak-client-webhook](https://github.com/chintanbuch/keycloak-client-webhook) |
| **Authentik** | Oui (flows) | Oui (groups, roles) | User Write stage + groupes ; flows personnalisables ; pas de webhook natif simple |
| **Apache Syncope** | Oui (Enduser UI) | Oui (roles, resources) | Provisioning vers « resources » (connectors) ; plus lourd (Jakarta EE, ConnId) |

- **Keycloak** : déjà dans l’archi ; User Profile (Keycloak 15+) permet des champs custom à l’inscription. Les event listeners ou plugins webhook permettent d’appeler une URL (CI) à l’inscription ou à la mise à jour de groupes.
- **Authentik** : flows + User Write stage pour assigner des groupes à l’inscription ; pas de « catalogue d’apps » ni de webhook standard pour déclencher une CI.
- **Apache Syncope** : self-service + provisioning vers des systèmes externes via connectors (LDAP, DB, REST, etc.) ; adapté entreprise, peut être trop lourd pour un homelab ; à évaluer si on veut un IdP + provisioning centralisé.

### 3.2 Catalogue d’applications (choix par l’utilisateur)

- **Backstage** : catalog de services + permissions ; orienté dev/platform, pas « famille choisit ses apps ».
- **Glance (homelab)** : dashboard avec liens vers les apps ; pas de « choix d’apps » ni de provisionnement.
- **Aucun produit trouvé** qui soit un pur « catalogue d’apps pour la famille » avec liste restreinte (hors admin) et sortie structurée (webhook / API) pour la CI.

**Conséquence** : le « catalogue » doit être soit :
- une **petite app dédiée** (page après première connexion : « Choisis tes apps » → enregistrement en DB/API + appel webhook vers la CI), soit
- **dérivé du IdP** : choix = attribution de groupes Keycloak/Authentik (ex. groupe `app-navidrome`, `app-nextcloud`) ; la CI réagit aux changements de groupes (webhook / poll / event).

### 3.3 Provisionnement vers les applications (création de comptes)

| Mécanisme | IdP | Apps cibles | Commentaire |
|-----------|-----|-------------|-------------|
| **SCIM** | Keycloak (plugins: keycloak-scim, scim-keycloak-bridge) | Apps qui parlent SCIM (peu en homelab) | Peu d’apps self-hosted avec SCIM ; plutôt entreprise/SaaS. |
| **Event listener / webhook** | Keycloak | CI (GitHub Actions, etc.) | CI reçoit « user created » ou « user groups updated » → scripts/API par app. |
| **API par app** | N/A | Navidrome, Nextcloud, etc. | Chaque app a son API admin (REST, CLI) ; la CI appelle ces APIs pour créer l’utilisateur + quotas. |
| **Syncope connectors** | Syncope | Tout ce pour quoi un connector existe (LDAP, DB, REST, etc.) | Centralisé mais coût de déploiement et de config. |

En pratique homelab : **CI déclenchée par webhook (Keycloak event)** + **scripts/API par service** (Navidrome, Nextcloud, Mealie, etc.) pour créer le compte et définir les ressources. Pas de SCIM nécessaire sauf si une app le supporte.

### 3.4 Références utiles

- [Keycloak : Enable Self-Registration](https://apipark.com/techblog/en/enable-keycloak-self-registration-for-users-a-guide/)
- [Keycloak User Provisioning (SCIM, automation)](https://hoop.dev/blog/keycloak-user-provisioning-a-complete-guide-to-automation-security-and-scalability/)
- [Keycloak event listener → webhook](https://stackoverflow.com/questions/57431092/keycloak-subscribe-events-like-create-user-to-trigger-a-webservice) ; [keycloak-webhook](https://github.com/vymalo/keycloak-webhook)
- [Authentik – User Write stage, groups](https://docs.goauthentik.io/docs/flow/stages/user_write)
- [Apache Syncope – Getting Started](https://syncope.apache.org/docs/getting-started.html)
- [GitLab Identity Platform – GitOps provisioning](https://handbook.gitlab.com/handbook/security/identity/platform/provisioning) (inspiration CI/CD)

---

## 4. Approche recommandée (composée)

Utiliser **Authentik** (choix homelab) et ajouter :

1. **Self-registration** : activer dans Authentik (Flows, Enrollment) + attributs custom si besoin.
2. **Catalogue « choix d’apps »** (hors admin/monitoring) :
   - **Option A** : Petite app « onboarding » (ex. après première connexion) : liste d’apps autorisées (Navidrome, Nextcloud, Mealie, etc.) → l’utilisateur coche → sauvegarde en base ou en attributs/groupes Authentik → webhook vers CI.
   - **Option B** : Utiliser uniquement les **groupes Authentik** comme « abonnements » (ex. `family-app-navidrome`, `family-app-nextcloud`). Une page simple (ou un formulaire post-login) ajoute/retire l’utilisateur de ces groupes ; un Notification Transport (webhook) Authentik sur changement de groupe déclenche la CI.
3. **CI (GitHub Actions ou équivalent)** :
   - Déclenchée par **webhook** (Authentik Notification Transports) : événements user created, group membership updated, etc.
   - Payload : `user_id`, `email`, `groups` (ou liste d’apps).
   - La CI exécute pour chaque app sélectionnée un script/API qui crée le compte (et applique quotas/ressources si l’app le permet).
4. **RBAC** :
   - **Admin / monitoring** : groupes Authentik dédiés (ex. `admin`, `monitoring`) ; pas proposés dans le catalogue famille.
   - **Apps famille** : accès via groupes mappés aux apps ; la CI ne crée des comptes que pour les apps dans la liste « catalogue famille ».

Résumé du flux :

```
[Première connexion] → Authentik (enrollment / invitation)
       ↓
[Page « Choisis tes apps »] → choix stocké (groupes Authentik ou DB onboarding)
       ↓
[Event / webhook] → CI (GitHub Actions ou autre)
       ↓
[CI] pour chaque app : appel API/script (Navidrome, Nextcloud, Mealie, …) → création compte + ressources
```

---

## 5. Options à trancher plus tard

- **IdP** : Authentik (choix homelab) ; Notification Transports pour webhooks.
- **Stockage du choix d’apps** : groupes Authentik uniquement vs table dédiée (app onboarding) avec webhook.
- **Quelles apps exposées dans le catalogue** : liste explicite (Navidrome, Nextcloud, Mealie, Komga, etc.) hors admin/monitoring ; à maintenir dans la config (YAML ou admin UI).
- **Ressources par app** : selon les APIs (quotas Nextcloud, limites Navidrome, etc.) ; à coder dans les scripts de la CI.

---

## 6. Synthèse

- **Pas de solution open source unique** qui fasse tout.
- **Recommandation** : composer **Authentik** (enrollment + groupes) + **catalogue « choix d’apps »** (petite app ou groupes) + **webhook → CI** (Notification Transports) qui crée les comptes par API/script dans chaque service avec les bonnes ressources.
- Ce document peut alimenter une epic « RBAC & onboarding familial » et des stories (Authentik enrollment, catalogue, webhook, CI par app).

---

## 7. Comparaison IdP : Keycloak vs Zitadel vs SuperTokens vs AuthKit

Pour le même use case (self-registration, RBAC, webhook → CI pour provisionnement), comparaison des alternatives à Keycloak.

### 7.1 Tableau comparatif

| Critère | Keycloak | Zitadel | SuperTokens | AuthKit (WorkOS) |
|--------|----------|---------|-------------|------------------|
| **Self-hosted** | Oui | Oui (ou Zitadel Cloud free) | Oui (Docker + PostgreSQL) | **Non** (SaaS uniquement) |
| **Self-registration** | Oui | Oui (local + social + org) | Oui | Oui (via WorkOS) |
| **RBAC / groupes** | Oui (groups, roles) | Oui (orgs, roles, actions) | Oui (User Roles recipe) | Oui |
| **Déclencher CI (webhook / event)** | Event Listener SPI ou plugins (keycloak-webhook) | **Actions v2** : webhooks sur events (user created, etc.) natifs | Pas de webhooks natifs ; à faire dans ton app (appel CI après signup) | Webhooks WorkOS possibles (SaaS) |
| **IdP pour apps tierces** | OIDC / SAML / LDAP ; très répandu | OIDC / SAML ; API-first | Principalement intégré dans *ton* app ; OIDC pour apps externes possible mais moins documenté pour Nextcloud, etc. | OIDC ; apps se connectent à WorkOS |
| **Ressources** | Lourd (JVM) | Léger (Go), tourne sur Raspberry Pi | Modéré | N/A (SaaS) |
| **UI / UX admin** | Puissant mais complexe | Moderne, orienté dev | Dashboard + SDK dans l’app | Moderne (hosted) |
| **Free tier (cloud)** | N/A (self-hosted) | Zitadel Cloud : 100 DAU, 1 instance, 1 admin, 3 IdP externes ; logs 30 min, audit 1 jour ; data US only | Self-hosted gratuit ; pas de « cloud free » IdP central | WorkOS : free tier selon plan (à vérifier) |

### 7.2 En bref

- **AuthKit (WorkOS)** : **pas self-hosted**. Si tu veux tout en local / contrôle des données, à écarter pour un homelab. Sinon, possible avec free tier WorkOS.

- **SuperTokens** : self-hosted, RBAC, bien pour **auth dans tes propres applications** (SDK backend + frontend). Pour un **IdP central** auquel se connectent Nextcloud, Navidrome, Grafana, etc., c’est moins le cas d’usage principal ; possible mais moins documenté (OIDC exposé pour clients externes). Pas de webhook « user created » natif → il faudrait que ton app d’onboarding appelle ta CI après inscription.

- **Zitadel** : **très bon candidat** si tu envisages de quitter Keycloak :
  - Self-hosted (ou Zitadel Cloud free avec limites).
  - **Actions v2** : webhooks sur events (user created, etc.) → déclencher ta CI sans plugin tiers.
  - Plus léger que Keycloak (Go), UI moderne, API-first.
  - OIDC/SAML comme IdP pour Nextcloud, Grafana, etc.
  - Free tier Cloud : 100 DAU, 1 admin, données US ; pour une famille c’est souvent suffisant ; pour self-hosted pas de limite.

- **Keycloak** : reste solide (déjà dans ton archi), écosystème énorme, plugins webhook existants. Plus lourd et UI admin moins agréable que Zitadel.

### 7.3 Recommandation pour ton homelab

- **Rester sur Keycloak** : pertinent si tu veux éviter une migration et que les plugins webhook (keycloak-webhook, etc.) te suffisent pour déclencher la CI.
- **Passer à Zitadel** : pertinent si tu veux un IdP plus léger, une UI plus claire et des **webhooks natifs** (Actions v2) pour « user created » / « group changed » → CI. Self-hosted recommandé pour garder le contrôle (pas de limite free tier, données chez toi).
- **SuperTokens** : à considérer si tu construis une ou plusieurs apps « maison » et que l’auth est au cœur de ton code ; pour « un IdP unique pour toute la famille + Nextcloud, Navidrome, etc. », Keycloak ou Zitadel restent plus adaptés.
- **AuthKit** : seulement si tu acceptes un IdP hébergé (WorkOS) et que le free tier te convient.
