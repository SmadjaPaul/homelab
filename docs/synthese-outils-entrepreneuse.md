# Synthèse : outils et sécurité pour Gwen

Résumé de la **stratégie**, des outils (coûts, fonctionnalités) et des risques / actions par ordre de priorité.

---

## Stratégie globale

**Principe : rien n’est stocké en local.** Les postes sont des terminaux de travail ; les données et l’accès sont centralisés et contrôlés.

| Pilier | Moyen | Rôle |
|--------|--------|------|
| **Aucune donnée en local** | **Fleet (FleetDM)** + **Ansible** | Fleet : MDM, inventaire, politiques, lock/wipe, visibilité (ex. USB). Ansible : configuration des postes (pas de stockage local persistant des données métier). |
| **Mail** | **Infomaniak** ou **Migadu** | Infomaniak : ~1 €/user/mois, API pour IaC (Ansible/Terraform custom). Migadu : Terraform natif (provider metio/migadu), prix par compte, illimité de boîtes. Les deux : IMAP/SMTP, MCP + IA. |
| **Mots de passe** | **Bitwarden** | Gratuit ou Famille ; à terme hébergement récupéré (self-host type Vaultwarden) pour rester gratuit avec partage d’équipe. |
| **Données** | **Nextcloud sur Hetzner** | Stockage central avec **contrôle fin et granulaire** des accès (droits par dossier, partages, groupes). Inclut les **prestataires externes** : accès limité par projet/dossier, révocable. |
| **Services support (hébergés)** | Homelab | **Odoo**, **Authentik**, **DocuSeal**, **Mattermost** ou **Element**, **base documentaire** (Docusaurus). SSO et outils métier sous son contrôle. |
| **Base documentaire** | **Docusaurus** + **Git** (+ **Obsidian** en local) | Documentation versionnée dans Git : qui a modifié quoi, traçabilité. Consultable et éditable en local avec **Obsidian** ; **Git = source de vérité** (pas de doublon, workflow clair). |

---

## 1. Outils – coûts et fonctionnalités

### Mail

| Outil | Coût | Fonctionnalités principales |
|------|------|------------------------------|
| **Migadu** (option IaC native) | Par compte : Micro ~19 €/an, Mini ~9 €/mois, etc. ; **illimité de boîtes** selon le plan | Mail pro (IMAP/SMTP), hébergement suisse. **IaC** : provider Terraform **metio/migadu** (mailboxes, alias, réponses auto). Compatible MCP + IA (MCP IMAP générique). |

### Mots de passe

| Outil | Coût | Fonctionnalités principales |
|------|------|------------------------------|
| **Bitwarden** | Gratuit ou Famille ; puis hébergement self-host (Vaultwarden) pour rester gratuit | Gestionnaire de mots de passe d’équipe, partage de coffres. À terme : hébergement récupéré pour garder le coût à zéro. |

### Données et stockage

| Outil | Coût | Fonctionnalités principales |
|------|------|------------------------------|
| **Nextcloud sur Hetzner** | Coût hébergement Hetzner + config | Fichiers, calendrier, contacts, partage. **Contrôle granulaire** : droits par dossier, groupes, partages externes (prestataires) avec accès limité et révocable. Aucune donnée métier persistante en local sur les postes. |

### Contrôle des postes (aucune donnée en local)

| Outil | Coût | Fonctionnalités principales |
|------|------|------------------------------|
| **Fleet (FleetDM)** | Gratuit (self-hosted) | MDM open source (macOS, Windows, Linux). Inventaire, politiques, scripts, lock/wipe. Visibilité USB (osquery). Partie “aucun stockage local” de la stratégie. |
| **Ansible** | Gratuit | Configuration et durcissement des postes (playbooks), cohérence de la flotte. Complète Fleet pour imposer la politique “pas de données en local”. |

### Endpoint Data Protection (DLP / blocage USB) – optionnel

| Outil | Coût | Fonctionnalités principales |
|------|------|------------------------------|
| **EndpointDLP (Somansa OSS)** | Gratuit (self-hosted) | À évaluer : DLP endpoint open source. Côté commercial : contrôle USB, impression, réseau, audit. Repo : [github.com/SomansaOpenSource/endpointdlp](https://github.com/SomansaOpenSource/endpointdlp). |
| **Endpoint Protector / Safetica / Purview** | Sur devis ou via M365 | DLP + blocage USB si besoin au-delà de la visibilité Fleet. |

### Services support hébergés (pour elle)

| Outil | Coût | Fonctionnalités principales |
|------|------|------------------------------|
| **Authentik** | Gratuit (self-hosted) | SSO (OIDC/SAML), centralisation des accès aux apps (Nextcloud, Odoo, Mattermost, etc.). |
| **Odoo** | Gratuit (Community) ou payant (modules) | CRM, ventes, facturation, stock, congés. |
| **DocuSeal** | Gratuit (self-hosted) | Signature électronique : contrats, NDA, avenants. |
| **Mattermost** ou **Element (Matrix)** | Gratuit (self-hosted) | Messagerie d’équipe, sous son contrôle. |
| **Base documentaire (Docusaurus)** | Gratuit (Git + hébergement) | **Documentation versionnée dans Git** : traçabilité (qui a modifié quoi). Consultable et éditable en local avec **Obsidian** ; **Git = source de vérité**. Idéal pour procédures, onboarding, savoir métier. |

### Autres outils utiles (optionnel)

| Outil | Coût | Fonctionnalités principales |
|------|------|------------------------------|
| **Snipe-IT** | Gratuit (self-hosted) | Inventaire matériel : qui a quel PC/téléphone, garanties. |

---

## 2. Risques et actions par ordre de priorité

### Priorité 1 – Stratégie “rien en local” et accès

| Risque | Action |
|--------|--------|
| Données sensibles en local sur les postes | **Fleet** + **Ansible** : politiques et config pour qu’aucune donnée métier ne soit stockée en local. Données centralisées sur **Nextcloud (Hetzner)**. |
| Mots de passe partagés ou faibles | **Bitwarden** (gratuit/Famille puis hébergement pour rester gratuit) ; formation de l’équipe. |
| Accès non centralisés aux apps | **Authentik** en SSO pour Nextcloud, Odoo, Mattermost/Element, DocuSeal, base doc. |

### Priorité 2 – Mail et stockage

| Risque | Action |
|--------|--------|
| Mail dispersé ou peu professionnel | **Infomaniak** (~1 €/user/mois) ou **Migadu** (Terraform natif, illimité de boîtes selon le plan) : boîtes pro, domaine dédié, MCP + IA. |
| Données non maîtrisées, pas de contrôle sur les partages | **Nextcloud sur Hetzner** avec droits **granulaires** (dossiers, groupes, partages externes pour prestataires, révocables). |

### Priorité 3 – Visibilité et réaction sur les postes

| Risque | Action |
|--------|--------|
| Pas de visibilité ni de moyen de réagir (vol, départ) | **Fleet** : inventaire, politiques, lock/wipe à distance. **Visibilité USB** (osquery). Si besoin de blocage : évaluer EndpointDLP ou solution payante (Endpoint Protector, Safetica, Purview). |

### Priorité 4 – Cadre juridique et opérationnel

| Risque | Action |
|--------|--------|
| Contrats / NDA non signés ou non tracés | **DocuSeal** (hébergé) pour signature électronique et archivage. |
| Procédures et savoir non formalisés | **Base documentaire Docusaurus** (Git) : versionnée, traçable ; édition locale possible avec **Obsidian**, Git comme source de vérité. |
| Pas de traçabilité du matériel | **Snipe-IT** (optionnel) pour inventaire des postes et équipements. |

### Priorité 5 – Croissance et gestion d’entreprise

| Risque | Action |
|--------|--------|
| Facturation / CRM / suivi dispersés | **Odoo** (hébergé) : CRM, facturation, congés. |
| Communication interne non maîtrisée | **Mattermost** ou **Element** (hébergés). |

### Priorité 6 – Hébergement pour un tiers (hébergeur)

| Risque | Action |
|--------|--------|
| Responsabilité en cas de perte de données ou indispo | Accord ou contrat écrit : périmètre, sauvegardes, restauration. |
| Mélange des données avec le reste du homelab | Isoler ses services (namespace dédié, voire tenant réseau). |
| Conformité (RGPD, etc.) | Elle reste responsable du traitement ; hébergeur fournit l’infra “sous son contrôle” uniquement. |

---

## 3. Récap ultra-court

- **Stratégie** : rien en local (Fleet + Ansible), mail **Infomaniak** (1 €/user) ou **Migadu** (Terraform natif), mots de passe **Bitwarden** (gratuit puis self-host), données **Nextcloud sur Hetzner** (accès fin et granulaire, y compris prestataires). **IaC** : Fleet + Ansible + Authentik déjà en Terraform ; mail = Migadu (Terraform) ou Infomaniak (API + Ansible).
- **Services hébergés pour elle** : Authentik, Odoo, DocuSeal, Mattermost ou Element, base documentaire **Docusaurus** (Git = source de vérité, édition locale avec Obsidian).
- **Priorités** : (1) Rien en local + Bitwarden + Authentik → (2) Infomaniak + Nextcloud Hetzner → (3) Fleet (visibilité / réaction) → (4) DocuSeal + doc Docusaurus + Snipe-IT → (5) Odoo + Mattermost/Element → (6) Cadre hébergeur.

---

## 4. Infrastructure as Code (IaC)

**Objectif : tout gérable en IaC** (Terraform, Ansible, GitOps).

| Domaine | En IaC aujourd’hui | Recommandation fournisseur |
|--------|---------------------|----------------------------|
| **Contrôle des postes** | **Fleet** : config en Git (politiques, scripts), déploiement GitOps. **Ansible** : playbooks pour configuration des postes. | Déjà couvert (Fleet + Ansible). |
| **Mail** | Infomaniak : API REST (boîtes, alias, dossiers) mais **pas de provider Terraform officiel** pour le mail (le provider Infomaniak est pour le Public Cloud uniquement). Possible en IaC “custom” (Ansible + API ou scripts Terraform + appels API). | **Migadu** (voir ci‑dessous) si priorité = Terraform natif. Sinon rester Infomaniak et piloter via API (Ansible ou petit module Terraform). |
| **Workplace (users, identité)** | **Authentik** : déjà en Terraform dans ton homelab (users, groups, applications). Pas de “workplace” type Google/Microsoft : identité = Authentik, postes = Fleet. | **Authentik + Fleet** = workplace côté homelab, tout en IaC. Pas besoin d’un fournisseur SaaS workplace dédié. |

### Recommandation : fournisseur mail + workplace en IaC

- **Mail en Terraform natif**
  **Migadu** ([migadu.com](https://migadu.com)) : provider Terraform **metio/migadu** (officiel sur le Registry). Gestion des **mailboxes**, alias, réponses auto, quotas, etc. en HCL. Prix **par compte** (pas par boîte) : Micro ~19 €/an, Mini ~9 €/mois, etc. ; **illimité de boîtes** selon le plan. Hébergement suisse. Pas de “workplace” (pas de gestion users/annuaire) : le workplace reste **Authentik + Fleet** (déjà en IaC).

- **Rester sur Infomaniak**
  Infomaniak propose une **API REST** (OAuth2) pour boîtes, alias, dossiers, réponses auto. Pas de provider Terraform mail ; tu peux :
  - faire de l’**Ansible** qui appelle l’API (modules custom ou `uri` + JSON), ou
  - un **module Terraform** (ressource `null` + `external` / script) qui wrappe l’API.
  Coût inchangé (~1 €/user/mois), hébergement suisse.

- **Workplace “tout-en-un” (users + mail) en Terraform**
  Si elle avait besoin d’un écosystème type Google/Microsoft :
  - **Google Workspace** : provider **hashicorp/googleworkspace** (users, groups, aliases, etc.). Mail = Gmail. Coût plus élevé.
  - **Microsoft 365** : providers **azuread** / **msgraph** (Entra ID, users, groups). Mail = Exchange Online. Idem, coût et dépendance à l’écosystème Microsoft.

**Synthèse** : pour **tout en IaC** sans changer d’écosystème, **Migadu** (mail en Terraform) + **Authentik** (identité, déjà en Terraform) + **Fleet** (postes, config en Git) couvrent mail + workplace. Si elle tient à **Infomaniak** (coût, confiance), garder Infomaniak et piloter le mail via **API + Ansible** (ou Terraform custom).

*Document mis à jour pour la stratégie “hébergement homelab pour Gwen – rien en local, Infomaniak / Migadu, Nextcloud Hetzner, Bitwarden, services support, base doc Docusaurus + Git + Obsidian, et IaC (Fleet, Ansible, Terraform)”.*
