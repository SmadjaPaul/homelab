# Stack identité / IdP homelab : besoins et inventaire des solutions

**Date** : 2026-01-31  
**Objectif** : D’abord cadrer les besoins, puis recenser les solutions possibles pour choisir la meilleure stack.

---

## Décision : Authentik retenu

**IdP choisi** : **Authentik**.  
Architecture et PRD mises à jour (architecture v6.0, PRD v2.0) : flux utilisateur avec **validation manuelle** avant accès aux apps, **apps d’administration non exposées** aux utilisateurs finaux, **service accounts** pour les connexions entre services (CI, ArgoCD, etc.), gestion en Terraform.

**Session de travail** : pour affiner le design (flux exact, liste apps famille vs admin, rôle de la CI, liste des service accounts), utiliser le document **session-travail-authentik.md** avec l’agent PM (workflow BMad *prd ou *create-epics). Voir `_bmad-output/planning-artifacts/session-travail-authentik.md`.

---

# Partie 1 — Besoins (à valider)

À valider ou ajuster avant de comparer les solutions. Chaque besoin est noté **obligatoire (O)** ou **souhaitable (S)**.

## 1.1 Hébergement et contrôle

| Id | Besoin | O/S | Détail |
|----|--------|-----|--------|
| H1 | **Self-hosted** | O | L’IdP tourne chez moi (Homelab ou OCI), pas de dépendance à un SaaS pour l’identité. |
| H2 | **Données en UE / contrôle** | S | Préférence données en Europe ou full self-hosted. |
| H3 | **Open source** | S | Code ouvert, pas de vendor lock-in. |

## 1.2 Authentification

| Id | Besoin | O/S | Détail |
|----|--------|-----|--------|
| A1 | **SSO (OIDC / OAuth2)** | O | Les apps (Nextcloud, Grafana, Vaultwarden, etc.) se connectent à l’IdP via OIDC. |
| A2 | **Self-registration** | O | La famille peut s’inscrire sans que l’admin crée les comptes à la main. |
| A3 | **Social login (Google, etc.)** | S | Optionnel : connexion avec Google / GitHub pour faciliter l’onboarding. |
| A4 | **MFA / passkeys** | S | 2FA ou passkeys pour renforcer la sécurité. |
| A5 | **Compatibilité oauth2-proxy / reverse proxy** | O | Utilisation derrière oauth2-proxy (ou équivalent) pour protéger les apps Tier 1. |

## 1.3 Autorisation et RBAC

| Id | Besoin | O/S | Détail |
|----|--------|-----|--------|
| R1 | **Groupes et/ou rôles** | O | Pouvoir distinguer « admin », « famille », et éventuellement « app X » (pour catalogue). |
| R2 | **Restriction catalogue** | O | Les utilisateurs « famille » ne voient/choisissent que des apps autorisées (pas admin, pas monitoring). |
| R3 | **Révocation centralisée** | O | Supprimer/désactiver un utilisateur dans l’IdP = plus d’accès aux apps protégées. |

## 1.4 Onboarding familial et provisionnement

| Id | Besoin | O/S | Détail |
|----|--------|-----|--------|
| P1 | **Déclencher une action après inscription** | O | À l’inscription (ou changement de « choix d’apps »), pouvoir appeler une URL / webhook pour déclencher une CI. |
| P2 | **CI crée les comptes dans les apps** | O | La CI crée les comptes (Navidrome, Nextcloud, Mealie, etc.) avec les bonnes ressources/quotas. |
| P3 | **Catalogue « choix d’apps »** | O | L’utilisateur choisit les apps qu’il veut parmi une liste restreinte (hors admin/monitoring). |

## 1.5 Intégration avec l’existant

| Id | Besoin | O/S | Détail |
|----|--------|-----|--------|
| I1 | **IdP pour apps tierces** | O | Nextcloud, Grafana, ArgoCD, Vaultwarden, Baïkal, n8n, etc. consomment OIDC depuis cet IdP. |
| **I4** | **Connexion avec Omni** | **O** | **Omni sert de proxy (UI, kubeconfig, talosctl) ; l’IdP doit pouvoir s’y connecter en SAML ou OIDC.** Sans ça, pas d’accès unifié aux clusters via Omni. |
| I2 | **Pas de changement d’URL pour les utilisateurs** | S | Les URLs des apps (Cloudflare Tunnel, etc.) restent inchangées ; seul l’IdP en amont peut changer. |
| I3 | **Kubernetes / Helm** | S | Déploiement possible sur le cluster (OCI ou Homelab) via Helm / manifests. |

## 1.5.1 Service accounts et IaC (type GCP)

| Id | Besoin | O/S | Détail |
|----|--------|-----|--------|
| **I5** | **Service accounts (identités machine)** | **O** | Comptes non-humains pour la CI, les services, les daemons : droits granulaires par « client » ou « machine user » (ex. CI = un service account avec accès limité, un autre pour ArgoCD, etc.). Équivalent GCP Service Account. |
| **I6** | **IaC pour service accounts** | **O** | Création / mise à jour des service accounts et de leurs rôles en **Terraform** (ou équivalent) : `terraform apply` pour définir qui a quels droits, versionné en Git. |

## 1.6 Opération et coût

| Id | Besoin | O/S | Détail |
|----|--------|-----|--------|
| O1 | **Ressources raisonnables** | O | IdP adapté à un homelab (RAM/CPU limités), pas un monstre type entreprise. |
| O2 | **Maintenabilité** | O | Doc claire, communauté ou écosystème actif. |
| O3 | **Free tier si cloud** | S | Si option cloud (ex. Zitadel Cloud), un free tier suffisant pour une famille (~5–10 users). |

---

## Synthèse des besoins (checklist pour toi)

À valider ou modifier :

- [ ] **H1** : Self-hosted obligatoire ?
- [ ] **A1, A2, A5** : SSO + self-registration + oauth2-proxy obligatoires ?
- [ ] **R1, R2, R3** : Groupes/rôles + catalogue restreint + révocation obligatoires ?
- [ ] **P1, P2, P3** : Webhook/event après inscription + CI provisionnement + catalogue « choix d’apps » obligatoires ?
- [ ] **I1** : IdP pour Nextcloud, Grafana, etc. obligatoire ?
- [ ] **I4** : Connexion avec Omni (SAML ou OIDC) obligatoire ?
- [ ] **I5, I6** : Service accounts (machine identities) + IaC (Terraform) obligatoires ?
- [ ] **O1, O2** : Ressources raisonnables + maintenabilité obligatoires ?
- [ ] **Souhaitables** : H2, H3, A3, A4, I2, I3, O3 — à confirmer ou ajouter.

**Besoins à ajouter ou retirer ?** (à compléter avant Partie 2)

---

# Partie 2 — Inventaire des solutions (recherche complète)

## 2.1 Liste des solutions identifiées

Solutions open source / self-hosted (ou avec option cloud free) couramment citées pour un IdP / SSO homelab ou petite structure.

| Solution | Type | Licence | Stack / langue | Remarque courte |
|----------|------|---------|----------------|------------------|
| **Keycloak** | IdP complet | Apache 2.0 | Java/JVM | Référence entreprise, lourd, écosystème énorme, plugins webhook. |
| **Zitadel** | IdP complet | Apache 2.0 / AGPL | Go | Léger, API-first, **Actions v2** = webhooks natifs sur events (user created, etc.). |
| **Authentik** | IdP complet | Apache 2.0 | Python | Flows visuels, groupes, **webhooks** (Notification Transports : user_write, login, authorize_application). |
| **Authelia** | Forward auth + OIDC | Apache 2.0 | Go | Très léger (~30 MB RAM), OIDC provider (Nextcloud, etc.), **pas de self-registration** (users en YAML/DB/CLI). |
| **Casdoor** | IdP UI-first | Apache 2.0 | Go | OIDC, SAML, CAS, LDAP, **webhooks** (signup, new-user, add-user). |
| **Ory (Kratos + Hydra)** | Identity + OAuth2/OIDC | Apache 2.0 | Go | Kratos = users/self-registration, Hydra = OAuth2/OIDC ; **headless** (API, UI à fournir ou ref). |
| **SuperTokens** | Auth library + IdP | Apache 2.0 | Node/TS (Core) | SSO, RBAC ; plutôt **intégré dans ton app** ; pas de webhook « user created » natif. |
| **AuthKit (WorkOS)** | IdP SaaS | Propriétaire | - | **Non self-hosted** ; free tier selon plan. |
| **Canaille** | IdP léger | AGPL | Python | OIDC, **self-registration**, MFA, groupes ; peu de doc sur webhooks. |
| **Rauthy** | IdP OIDC | Apache 2.0 | Rust | Léger, OIDC, passkeys ; à vérifier webhooks/events. |
| **LemonLDAP::NG** | IdP / SSO | GPL | Perl | AAA, CAS/SAML/OIDC, 60+ apps ; plus entreprise, lourd. |
| **Apereo CAS** | IdP / SSO | Apache 2.0 | Java | Entreprise, CAS/SAML/OAuth2/OIDC ; self-registration via extensions. |
| **Apache Syncope** | IdM + provisioning | Apache 2.0 | Java (Jakarta EE) | Provisioning vers ressources (connectors) ; Enduser UI ; lourd. |
| **Gluu** | IdP / IdM | - | - | OIDC, SAML ; complexité déploiement. |
| **PrivacyIDEA** | 2FA / MFA | AGPL | Python | Focus 2FA (TOTP, U2F, etc.) ; pas un IdP SSO complet. |
| **WSO2 Identity Server** | IdP entreprise | Apache 2.0 | Java | Complet mais lourd, orienté entreprise. |

---

## 2.2 Mapping besoins → solutions (critères obligatoires)

Critères **obligatoires** du § 1 : self-hosted (H1), SSO OIDC (A1), self-registration (A2), oauth2-proxy compatible (A5), groupes/rôles (R1), catalogue restreint possible (R2), révocation centralisée (R3), **webhook/event après inscription** (P1), IdP pour apps tierces (I1), **connexion Omni (I4)**, **service accounts (I5)**, **IaC Terraform (I6)**, ressources raisonnables (O1), maintenabilité (O2).

| Solution | H1 | A1 | A2 | A5 | R1 | R2 | R3 | P1 (webhook) | I1 | **I4 Omni** | **I5 SA** | **I6 IaC** | O1 | O2 |
|----------|----|----|----|----|----|----|----|--------------|----|-------------|-----------|------------|----|-----|
| **Keycloak** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (plugins/SPI) | ✅ | ✅ doc Sidero | ✅ **Service account** (client) | ✅ **Terraform officiel** | ⚠️ lourd | ✅ |
| **Zitadel** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ **natif (Actions v2)** | ✅ | ✅ SAML (générique) | ✅ **Machine user** | ✅ **Terraform officiel** | ✅ léger | ✅ |
| **Authentik** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ **natif (Transports)** | ✅ | ✅ **doc intégration** | ✅ **Service account** (user) | ✅ **Terraform** (goauthentik) | ✅ modéré | ✅ |
| **Authelia** | ✅ | ✅ | ❌ | ✅ | ⚠️ limité | ⚠️ | ✅ | ❌ | ✅ | ⚠️ OIDC (à vérifier) | ❌ | ⚠️ | ✅ très léger | ✅ |
| **Casdoor** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ **natif (webhooks)** | ✅ | ✅ SAML (générique) | ⚠️ à vérifier | ⚠️ à vérifier | ✅ | ✅ |
| **Ory (Kratos+Hydra)** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ à coder (API) | ✅ | ⚠️ SAML/OIDC (à config) | ⚠️ (Hydra clients) | ✅ Terraform Ory | ✅ | ✅ |
| **SuperTokens** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ (dans ton app) | ⚠️ moins IdP central | ⚠️ à vérifier | ⚠️ | ⚠️ | ✅ | ✅ |
| **AuthKit** | ❌ SaaS | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ? | ✅ | ? | ? | - | - | ✅ |
| **Canaille** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ? à vérifier | ✅ | ⚠️ OIDC (à config) | ? | ? | ✅ | ⚠️ moins connu |
| **Rauthy** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ? à vérifier | ✅ | ⚠️ OIDC (à config) | ? | ? | ✅ | ✅ |
| **LemonLDAP::NG** | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ | ✅ | ? | ✅ | ⚠️ SAML (à config) | ? | ? | ⚠️ lourd | ✅ |
| **Apereo CAS** | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ | ✅ | ? | ✅ | ⚠️ SAML (à config) | ? | ⚠️ | ⚠️ lourd | ✅ |
| **Apache Syncope** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (connectors) | ✅ | ⚠️ SAML (à config) | ⚠️ | ? | ❌ lourd | ✅ |

**Légende** : ✅ = oui / adapté ; ⚠️ = partiel ou à vérifier ; ❌ = non ou inadapté.

**I4 Omni** : Omni accepte [SAML](https://omni.siderolabs.com/how-to-guides/using-saml-with-omni) et OIDC. **Keycloak** : [Configure Keycloak for Omni](https://docs.siderolabs.com/omni/infrastructure-and-extensions/self-hosted/configure-keycloak-for-omni) (doc officielle Sidero, SAML). **Authentik** : [Integrate with Omni](https://integrations.goauthentik.io/infrastructure/omni/) (guide communauté, SAML). Zitadel, Casdoor, etc. : SAML/OIDC générique (Omni configuré en SP, IdP = Zitadel/Casdoor) ; pas de guide « Omni » dédié mais faisable.

**I5 (service accounts) / I6 (IaC)** : **Keycloak**, **Zitadel** et **Authentik** supportent les **service accounts** (identités machine, droits granulaires pour CI/services) et un **provider Terraform** pour les gérer en IaC. Voir § 2.2.2.

**Points clés** :
- **Authelia** : pas de self-registration → à écarter si besoin famille « s’inscrire tout seul ».
- **P1 (webhook)** : Zitadel (Actions v2), Authentik (Notification Transports), Casdoor (webhooks), Keycloak (plugins/SPI) couvrent le besoin ; Ory/SuperTokens nécessitent du code côté app.
- **O1 (ressources)** : Zitadel, Authentik, Casdoor, Authelia, Canaille, Rauthy = raisonnables ; Keycloak, CAS, Syncope, LemonLDAP = plus lourds.
- **I4 (Omni)** : Keycloak et Authentik ont une **doc dédiée** ; les autres IdP SAML/OIDC sont utilisables avec une config générique côté Omni.

---

## 2.2.1 Connexion avec Omni (détail)

Omni sert de **proxy** pour l’accès aux clusters (UI web, kubeconfig, talosctl). L’authentification des utilisateurs Omni doit donc passer par ton IdP.

**Ce que supporte Omni** :
- **SAML 2.0** : documenté ([Using SAML with Omni](https://omni.siderolabs.com/how-to-guides/using-saml-with-omni), [SAML and ACLs](https://omni.siderolabs.com/tutorials/configure-saml-and-acls)). Omni = Service Provider (SP), ton IdP = Identity Provider (IdP). Utilisateurs créés à la première connexion ; attributs SAML → labels Identity.
- **OIDC** : supporté (ex. [OIDC with Tailscale](https://siderolabs-fe86397c.mintlify.app/omni/security-and-authentication/oidc-login-with-tailscale)).

**IdP avec guide dédié pour Omni** :

| IdP | Protocole | Documentation |
|-----|------------|----------------|
| **Keycloak** | SAML | [Configure Keycloak for Omni](https://docs.siderolabs.com/omni/infrastructure-and-extensions/self-hosted/configure-keycloak-for-omni) (Sidero, officielle) |
| **Authentik** | SAML | [Integrate with Omni](https://integrations.goauthentik.io/infrastructure/omni/) (Authentik, communauté) |

**Autres IdP** : Zitadel, Casdoor, Ory, etc. exposent SAML et/ou OIDC ; on configure Omni en SP avec l’URL metadata / issuer de l’IdP. Pas de guide « Omni » prêt-à-l’emploi mais faisable (SAML : ACS URL `https://omni.<ton-domaine>/saml/acs`, Audience, mappers email/name, etc.).

**Conclusion** : Le besoin **I4 (connexion Omni)** est couvert par tout IdP qui parle SAML ou OIDC. Keycloak et Authentik ont une procédure explicite ; les autres demandent une config générique SAML/OIDC côté Omni.

---

## 2.2.2 Service accounts (type GCP) et IaC

Tu veux des **service accounts** (identités machine) avec droits granulaires pour la CI et les services, et pouvoir tout définir en **IaC** (Terraform). Les trois solutions du Top 3 le supportent.

### Comparatif service accounts + IaC

| Solution   | Service accounts / machine identities | Droits granulaires | Terraform / IaC |
|------------|----------------------------------------|--------------------|------------------|
| **Keycloak** | **Service accounts** par client OIDC : client confidentiel + « Service Accounts Enabled ». Client Credentials flow (clientId + clientSecret). Rôles assignables au service account (realm roles, client roles). | Oui : **Service Account Roles** (realm + client) ; rôles par client = un « compte » par usage (CI, ArgoCD, etc.). | **Terraform provider officiel** [keycloak/keycloak](https://registry.terraform.io/providers/keycloak/keycloak/latest/docs) : `keycloak_openid_client` (service_accounts_enabled), `keycloak_openid_client_service_account_realm_role`, `keycloak_openid_client_service_account_role`. Apply en IaC pour clients + rôles. |
| **Zitadel** | **Machine users** (service users) : Client Secrets, Machine Keys (JWT), Personal Access Tokens (PAT). Client Credentials flow. | Oui : **Project roles** ; machine user = un « compte » par usage ; rôles par projet/org. | **Terraform provider officiel** [zitadel/zitadel](https://registry.terraform.io/providers/zitadel/zitadel/latest/docs) : machine users, project roles, secrets. [Doc Zitadel Terraform](https://zitadel.com/docs/guides/manage/terraform-provider). Apply en IaC. |
| **Authentik** | **Service accounts** : utilisateurs de type `service_account` (Directory > Users > Create Service Account). Tokens avec expiration (API Token, App password). Pas de login UI. | Oui : **groupes / permissions** sur le service account ; un compte par usage (CI, service X). | **Terraform provider** [goauthentik/authentik](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs) : `authentik_user` avec `type = "service_account"`. [Doc Authentik Service Accounts](https://docs.goauthentik.io/sys-mgmt/service-accounts/). Apply en IaC. |

### En résumé

- **Keycloak** : Service account = client OIDC confidentiel avec « Service Accounts Enabled » ; rôles = realm roles + client roles. Terraform : `keycloak_openid_client` + `keycloak_openid_client_service_account_realm_role` / `_role`. Très granulaire (un client = un service account, rôles au choix).
- **Zitadel** : Machine user = entité dédiée ; auth par Client Secret, JWT (Machine Key) ou PAT. Terraform : provider officiel, machine users + project roles. API-first, conçu pour l’automatisation.
- **Authentik** : Service account = user avec `type = service_account` ; tokens dans Directory > Tokens. Terraform : `authentik_user` + type. Droits via groupes/policies Authentik.

**Références** : [Keycloak Service Accounts](https://www.keycloak.org/docs/latest/securing_apps/#_service_accounts), [Zitadel Machine User / Client Credentials](https://zitadel.com/docs/guides/integrate/service-users/client-credentials), [Authentik Service Accounts](https://docs.goauthentik.io/sys-mgmt/service-accounts/), [Authentik M2M](https://goauthentik.io/blog/2023-09-26-machine-to-machine-communication-in-authentik) ; Terraform : [Keycloak provider](https://registry.terraform.io/providers/keycloak/keycloak/latest/docs), [Zitadel provider](https://zitadel.com/docs/guides/manage/terraform-provider), [Authentik provider](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/user).

---

## 2.3 Synthèse par profil

- **Profil « tout-en-un, webhook natif, léger »**  
  → **Zitadel** ou **Authentik** ou **Casdoor**.  
  Zitadel : Actions v2 très claires pour « user created » → CI. Authentik : webhooks (user_write, etc.) + flows. Casdoor : webhooks signup/new-user.

- **Profil « déjà Keycloak, pas de migration »**  
  → Rester sur **Keycloak** + plugin webhook (keycloak-webhook) ou Event Listener SPI.

- **Profil « forward auth minimal, pas de self-registration »**  
  → **Authelia** (si les comptes sont créés autrement, ex. admin ou script).

- **Profil « IdP headless / API-first »**  
  → **Ory (Kratos + Hydra)** ; UI à fournir ou utiliser la ref (ex. kratos-selfservice-ui-react-nextjs).

- **Profil « auth dans mon app, pas IdP central pour 10 apps »**  
  → **SuperTokens** possible ; pour Nextcloud + Grafana + …, Keycloak/Zitadel/Authentik/Casdoor restent plus adaptés.

- **Profil « SaaS OK »**  
  → **AuthKit (WorkOS)** si free tier suffit ; pas self-hosted.

---

## 2.4 Recommandation (après accord sur les besoins)

Si les besoins Partie 1 sont validés (en particulier **self-registration**, **webhook après inscription**, **IdP pour apps tierces**, **connexion Omni (I4)**, **ressources raisonnables**) :

1. **Premier choix** : **Zitadel** (self-hosted) — webhooks natifs (Actions v2), léger, UI claire, OIDC pour Nextcloud/Grafana/etc. ; Omni en SAML générique.
2. **Alternatives** : **Authentik** (webhooks natifs, flows, **doc Omni dédiée**) ou **Casdoor** (webhooks signup) si tu préfères leur écosystème ou stack.
3. **Sans migrer** : **Keycloak** + plugin keycloak-webhook ou Event Listener pour P1 ; **doc Omni officielle Sidero**.

À exclure pour ton cas si self-registration + webhook sont obligatoires : **Authelia** (pas de self-registration), **AuthKit** (si self-hosted obligatoire).

---

## 2.5 Top 3 (pour ton homelab)

Critères : tous les besoins obligatoires (H1, A1, A2, A5, R1–R3, P1, I1, **I4 Omni**, O1, O2), plus simplicité déploiement, écosystème homelab, et aspect **multi-service** (un seul IdP pour Omni + Nextcloud + Grafana + Vaultwarden + …).

### 1. Authentik

**Pourquoi en tête** :
- **Doc dédiée Omni** ([Integrate with Omni](https://integrations.goauthentik.io/infrastructure/omni/)) : config SAML prête à l’emploi, pas de reverse-engineering.
- **Webhooks natifs** (Notification Transports) : `user_write`, `login`, `authorize_application` → déclencher ta CI sans plugin tiers.
- **Multi-service** : un seul IdP pour Omni, Nextcloud, Grafana, ArgoCD, Vaultwarden, etc. ; [nombreuses intégrations](https://integrations.goauthentik.io/) (dont Omni, Keycloak, MinIO, Harbor, …).
- Très cité en **homelab** (r/selfhosted, comparatifs 2024–2025) ; UI claire, flows visuels pour personnaliser l’auth.
- Self-registration, groupes, rôles, OIDC + SAML ; ressources **modérées** (PostgreSQL + Redis).

**Inconvénients** : Dépendance PostgreSQL + Redis ; pas d’Actions type Zitadel (webhooks = Notification Rules + Transports, à configurer).

**Références** : [Authentik vs Zitadel 2025](https://www.houseoffoss.com/post/zitadel-vs-authentik-which-identity-provider-should-you-use-in-2025), [4 reasons Authentik](https://xda-developers.com/authentik-is-the-best-secure-sign-in-solution).

---

### 2. Zitadel

**Pourquoi en top 3** :
- **Webhooks natifs (Actions v2)** : events « user created », « user updated », etc. → appeler ta CI sans plugin ; très adapté au flux onboarding + provisionnement.
- **Léger** (Go), API-first, UI moderne ; self-registration, orgs, SAML + OIDC.
- **Omni** : pas de guide « Omni » dédié, mais Zitadel expose SAML ; config Omni en SP avec metadata Zitadel (faisable, [SAML Zitadel](https://zitadel.com/docs/guides/integrate/login/saml)).
- Multi-service : un IdP pour Omni + toutes les apps OIDC/SAML.
- Souvent recommandé pour **scale / API** ; pour un homelab avec CI/webhooks, Actions v2 est un vrai plus.

**Inconvénients** : Pas de page « Integrate with Omni » comme Authentik ; il faut suivre la doc SAML générique Omni + Zitadel.

**Références** : [Zitadel vs Authentik 2025](https://www.houseoffoss.com/post/zitadel-vs-authentik-which-identity-provider-should-you-use-in-2025), [State of Open-Source Identity 2025](https://www.houseoffoss.com/post/the-state-of-open-source-identity-in-2025-authentik-vs-authelia-vs-keycloak-vs-zitadel).

---

### 3. Keycloak

**Pourquoi en top 3** :
- **Doc officielle Sidero pour Omni** ([Configure Keycloak for Omni](https://docs.siderolabs.com/omni/infrastructure-and-extensions/self-hosted/configure-keycloak-for-omni)) : SAML pas à pas, mappers, client Keycloak.
- **Déjà dans ton archi** : pas de migration si tu restes dessus ; écosystème énorme, plugins (keycloak-webhook, etc.) pour P1.
- **Multi-service** : référence pour « un IdP pour tout » (Nextcloud, Grafana, Omni, …) ; OIDC + SAML, groupes, rôles, self-registration.
- Battle-tested, LDAP/federation, User Profile (champs custom à l’inscription).

**Inconvénients** : **Lourd** (JVM), UI admin complexe ; webhooks = plugin ou Event Listener SPI (pas natif comme Authentik/Zitadel).

**Références** : [Configure Keycloak for Omni](https://docs.siderolabs.com/omni/infrastructure-and-extensions/self-hosted/configure-keycloak-for-omni), [Keycloak vs Zitadel](https://zitadel.com/blog/zitadel-vs-keycloak).

---

## Synthèse Top 3

| Rang | Solution   | Atout principal                          | Omni                    | Webhook (P1)     | **Service accounts + IaC** | Ressources |
|------|------------|------------------------------------------|-------------------------|------------------|----------------------------|------------|
| **1** | **Authentik** | Doc Omni dédiée + multi-service + homelab | ✅ Guide dédié (SAML)   | ✅ Natif (Transports) | ✅ Service account (user) + Terraform | Modéré     |
| **2** | **Zitadel**  | Actions v2 (webhooks natifs) + léger     | ✅ SAML générique       | ✅ Natif (Actions v2) | ✅ **Machine user** + Terraform officiel | Léger      |
| **3** | **Keycloak** | Doc Sidero Omni + déjà dans l’archi       | ✅ Guide officiel (SAML)| ✅ Plugin/SPI    | ✅ **Service account** (client) + Terraform officiel | Lourd      |

**Multi-service** : les trois font « un IdP pour Omni + Nextcloud + Grafana + … ». Authentik ajoute beaucoup d’intégrations prêtes (dont Omni) ; Keycloak et Zitadel couvrent le même cas avec SAML/OIDC générique.

**Service accounts (type GCP) + IaC** : les trois supportent des **identités machine** avec droits granulaires (un « compte » par CI, par ArgoCD, etc.) et un **provider Terraform** pour les créer/gérer en `terraform apply`. Voir § 2.2.2.

**Choix pratique** :
- Tu veux **zéro prise de tête sur Omni** et une stack homelab très répandue → **Authentik**.
- Tu veux **webhooks/CI au cœur** et une stack légère/API-first → **Zitadel**.
- Tu restes sur **Keycloak** (déjà prévu) et tu acceptes un plugin pour les webhooks → **Keycloak**.

---

## 2.6 Références

- [Comparatif 11 solutions SSO (lacontrevoie)](https://lacontrevoie.fr/en/blog/2024/comparatif-de-onze-solutions-de-sso-libres/)
- [Authentik vs Authelia vs Keycloak (elest.io, 2026)](https://blog.elest.io/authentik-vs-authelia-vs-keycloak-choosing-the-right-self-hosted-identity-provider-in-2026/)
- [Zitadel Actions v2](https://zitadel.com/docs/concepts/features/actions_v2)
- [Authentik Events & Transports](https://docs.goauthentik.io/sys-mgmt/events/event-actions/)
- [Casdoor Webhooks](https://casdoor.github.io/docs/webhooks/overview)
- [Keycloak Event Listener / keycloak-webhook](https://github.com/vymalo/keycloak-webhook)
- [Ory Kratos Self-service registration](https://ory.sh/docs/kratos/self-service/flows/user-registration)
- [Authelia – no self-registration (users file/CLI)](https://www.authelia.com/configuration/first-factor/file/)
- [Canaille](https://canaille.readthedocs.io/)
- [Rauthy](https://sebadob.github.io/rauthy/)
- **Omni** : [Using SAML with Omni](https://omni.siderolabs.com/how-to-guides/using-saml-with-omni) ; [Configure Keycloak for Omni](https://docs.siderolabs.com/omni/infrastructure-and-extensions/self-hosted/configure-keycloak-for-omni) ; [Integrate Authentik with Omni](https://integrations.goauthentik.io/infrastructure/omni/)
