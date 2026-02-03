---
sidebar_position: 3
---

# Conclusions de planification (résumé)

Résumé des **conclusions** issues des documents de planification (product brief, stack identité, décisions invitation/Cloudflare, session Authentik). Les documents sources ont été archivés ; seules les décisions finales sont conservées ici.

---

## 1. Product Brief — Vision et principes

**Vision** : Homelab self-hosted, géré en Infrastructure-as-Code (IaC), pour l’indépendance vis-à-vis des GAFAM, avec stockage centralisé, media streaming, gaming et services extensibles. Architecture hybride : local (Proxmox/NAS) + Oracle Cloud (Always Free) pour les services exposés.

**Proposition de valeur** : **Maintenabilité assistée par l’IA**, via l’IaC comme mécanisme (versioning, tests, assistance IA) sans exiger une expertise sysadmin poussée.

**Principes retenus** :
1. **Maintenabilité + IA** → Infra déclarative (Terraform, K8s, etc.).
2. **Contrôle + indépendance** → Self-hosting stratégique (cloud en complément si pertinent).
3. **Gaming** → Virtualisation ciblée (Windows / Steam OS).
4. **Efficacité énergétique** → Wake-on-LAN, planning d’uptime.
5. **Code comme source de vérité** → Versioning, rollback, collaboration.
6. **Extensibilité** → Architecture modulaire, ajout de services par l’IaC.

**Différenciateurs** : IaC pour maintenabilité, architecture modulaire, self-hosting stratégique, hybrid cloud (OCI Always Free), remplacement GAFAM (Nextcloud, Jellyfin, Immich, etc.).

---

## 2. Stack identité — Authentik retenu

**Décision** : **Authentik** est l’IdP retenu.

- Architecture et PRD alignées : flux avec **validation manuelle** avant accès aux apps, **apps d’administration non exposées** aux utilisateurs finaux, **service accounts** pour les connexions entre services (CI, ArgoCD, etc.), gestion en Terraform.
- **Omni** : intégration documentée (SAML) ; webhooks natifs (Notification Transports) ; multi-service (Omni, Nextcloud, Grafana, ArgoCD, etc.) ; ressources modérées (PostgreSQL + Redis) ; provider Terraform (goauthentik/authentik).

**Alternatives écartées pour ce projet** : Keycloak (plus lourd), Zitadel (pas de guide Omni dédié). Authelia écartée car pas de self-registration.

---

## 3. Décision : invitation-only et trafic via Cloudflare

### 3.1 Onboarding par invitation uniquement

| Avant | Après |
|-------|--------|
| Self-registration ouverte | **Self-registration désactivée**. Aucun compte sans **lien d’invitation** (token). |

- **Justification** : Surface d’attaque réduite, onboarding intentionnel, alignement bonnes pratiques.
- **Implémentation** : Enrollment uniquement avec token d’invitation (Stage Invitation). Création des invitations via **UI Authentik** (Directory → Invitations) ou **API** ; pas de ressource Terraform pour les invitations.

### 3.2 Trafic utilisateur via Cloudflare

**Décision** : **Toutes** les connexions des utilisateurs finaux (auth, portail Authentik, apps protégées) **transitent par Cloudflare**. Aucun accès direct à l’origine pour le trafic utilisateur.

- **Justification** : Point d’entrée unique, cohérence avec l’architecture (Tunnel), renforcement (WAF, DDoS sur tout le trafic).
- **Implémentation** : Authentik et apps « famille » accessibles uniquement via les hostnames du Cloudflare Tunnel ; pas d’exposition directe par IP ou autre domaine.

---

## 4. Session Authentik — Décisions de design

### 4.1 Flux utilisateur

1. **Admin** crée une invitation (UI ou API) et envoie le lien.
2. **Utilisateur** clique sur le lien, complète l’enrollment (mot de passe, etc.).
3. **Admin** ajoute aux groupes si besoin.
4. **Accès aux apps** selon les groupes (policies Authentik).
5. **Webhook** (optionnel) → CI provisionne les comptes dans les apps (Nextcloud, Navidrome, etc.).

**Validation** : Manuelle dans Authentik (ajout aux groupes). Job CI « valider user » optionnel.

### 4.2 Apps famille vs admin

| Catégorie | Exemples | Exposition |
|-----------|----------|------------|
| **Apps famille** | Nextcloud, Vaultwarden, Baïkal, Navidrome, Mealie, Glance, Immich, n8n | Via Cloudflare Tunnel ; protégées par Authentik ; visibles dans « My applications » selon groupes. |
| **Apps admin** | Authentik Admin, Omni UI, ArgoCD, Grafana, Prometheus, Alertmanager, ntfy | **Non exposées** aux utilisateurs finaux ; accès réservé au groupe `admin`. |

### 4.3 CI

- **Validation** : Dans Authentik (source de vérité).
- **Provisionnement** : Webhook Authentik (event `user_write` ou groupe) → CI crée les comptes dans les apps. Alternative : job CI manuel.

### 4.4 Service accounts

- **Usage** : CI (`ci-github`), ArgoCD, backup, n8n — un compte par usage, droits minimaux.
- **IaC** : Définis en **Terraform** (provider goauthentik/authentik) ; `terraform apply` pour créer/mettre à jour.
- **Secrets** : Tokens dans un secret manager (Bitwarden / ESO) ; jamais en clair dans le repo.

### 4.5 Groupes (nominaux)

- `admin` — accès admin.
- `family-validated` — utilisateur validé.
- `family-app-nextcloud`, `family-app-navidrome`, etc. — selon besoin ; ou un seul groupe `family-validated` avec policy par application.

---

## 5. Synthèse

| Thème | Conclusion |
|-------|------------|
| **Vision** | Homelab IaC, maintenabilité assistée par l’IA, hybride local + OCI Always Free. |
| **IdP** | Authentik (SSO, Omni, webhooks, service accounts, Terraform). |
| **Onboarding** | Invitation uniquement ; pas de self-registration ouverte. |
| **Trafic utilisateur** | Uniquement via Cloudflare (Tunnel) ; pas d’accès direct à l’origine. |
| **Apps** | Famille vs admin ; apps admin non exposées au portail famille. |
| **Provisionnement** | Webhook Authentik → CI (recommandé) ou job manuel. |
| **Service accounts** | Terraform ; secrets dans secret manager. |
