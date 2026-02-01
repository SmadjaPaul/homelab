# Décision : invitation-only et trafic utilisateur via Cloudflare

**Date** : 2026-02-01  
**Contexte** : Revue des décisions de gestion des utilisateurs (Architect).  
**Références** : `session-travail-authentik.md`, `architecture-proxmox-omni.md`, discussion bonnes pratiques identité.

---

## 1. Décision : passage à l’onboarding par invitation uniquement

### 1.1 Choix

| Avant | Après |
|-------|--------|
| **Self-registration activé** : toute personne pouvait créer un compte ; l’admin validait ensuite (ajout aux groupes). | **Self-registration désactivé** : aucun compte créé sans invitation. Seuls les utilisateurs ayant reçu un **lien d’invitation** (token) peuvent compléter l’enrollment (définir leur mot de passe, etc.). |

### 1.2 Justification

- **Surface d’attaque réduite** : plus de page d’inscription publique exposée sur Internet → moins de risque de spam, bots ou abus.
- **Onboarding intentionnel** : seuls les comptes explicitement invités existent ; contrôle fin sur qui accède au homelab.
- **Alignement avec les bonnes pratiques** : pas d’accès sans contrôle, création de comptes uniquement sur action explicite de l’admin.

### 1.3 Impact sur les specs

- **session-travail-authentik.md** §6.1 : à mettre à jour — remplacer « Self-registration activé » par « **Onboarding par invitation uniquement** » (self-registration désactivé ; flux d’enrollment accessible uniquement avec un token d’invitation).
- **PRD / Architecture** : refléter que l’inscription n’est plus ouverte ; le flux utilisateur devient : **Invitation (admin) → Lien envoyé à l’utilisateur → Enrollment (mot de passe, etc.) → Accès aux apps selon les groupes** (éventuellement pré-assignés dans le flow d’invitation via User Write Stage).
- **Implémentation** : configurer Authentik pour que l’enrollment public (sans token) soit désactivé ; utiliser un flow d’enrollment avec **Stage Invitation**. Création des invitations via **UI Authentik** (Directory → Invitations) ou **API** (`POST /api/v3/stages/invitation/invitations/`) — le provider Terraform n’a pas de ressource `authentik_invitation`, donc les invitations restent hors Terraform (script/CI ou UI).

---

## 2. Bonnes pratiques identité : non encore implémentées

À traiter en phase ultérieure ou dans les stories existantes :

| Pratique | État | Action suggérée |
|----------|------|------------------|
| **MFA pour comptes sensibles** | Non obligatoire aujourd’hui | Activer MFA (TOTP / passkeys) au moins pour le groupe `admin` ; optionnel pour les apps famille sensibles (ex. Vaultwarden). |
| **Traçabilité (audit)** | Non documenté | Vérifier les event logs Authentik (qui a ajouté qui à quel groupe) ; documenter où les consulter et la rétention. |
| **Rotation des secrets** | Mentionnée dans l’implémentation, pas de runbook | Rédiger un runbook : rotation du token Terraform, rotation des tokens des service accounts, mise à jour ESO. |
| **Sécurisation du webhook de provisionnement** | À faire si webhook utilisé | URL non prévisible, vérification de signature/payload si l’API le permet ; appels limités au réseau/CI autorisés. |

La décision **invitation-only** couvre déjà les pratiques « surface d’attaque minimale » et « onboarding intentionnel ».

---

## 3. Décision : trafic utilisateur via Cloudflare

### 3.1 Choix

**Toutes les connexions des utilisateurs finaux** (authentification, portail Authentik, apps protégées) **doivent transiter par Cloudflare**. Aucun accès direct à l’origine (Authentik ou apps) pour le trafic utilisateur.

### 3.2 Justification

- **Point d’entrée unique** : un seul chemin (Cloudflare Tunnel + proxy Cloudflare) pour le trafic utilisateur → règles de sécurité et WAF appliquées au même endroit.
- **Cohérence avec l’architecture** : l’architecture prévoit déjà Cloudflare Tunnel (pas de ports ouverts) ; cette décision formalise que l’on s’appuie sur Cloudflare pour tout le trafic utilisateur et que l’on peut y ajouter des règles (WAF, pays, bots, etc.).
- **Renforcement** : en s’assurant qu’aucun accès utilisateur n’échappe à Cloudflare, on garantit que DDoS, WAF et éventuelles règles (ex. géo, challenge) s’appliquent à toutes les connexions utilisateur.

### 3.3 Implémentation

| Mesure | Description |
|--------|-------------|
| **Exposition uniquement via Tunnel** | Authentik et les apps « famille » ne sont accessibles que via les hostnames configurés dans Cloudflare Tunnel (pas d’exposition directe par IP ou autre domaine). |
| **Règle Cloudflare (optionnel)** | Si besoin de durcir : configurer une règle WAF ou une politique Cloudflare pour que seules les requêtes ayant transité par le proxy Cloudflare soient considérées (ex. bloquer l’accès direct au hostname d’origine si jamais exposé par erreur ; ou utiliser les en-têtes Cloudflare côté origine pour rejeter les requêtes qui ne viennent pas du proxy). Avec Tunnel, le trafic vers l’origine vient déjà de cloudflared ; la règle peut viser à **n’accepter que le trafic entrant par les routes Tunnel** et à documenter qu’aucun autre point d’entrée utilisateur n’est autorisé. |
| **Documentation** | Documenter dans l’architecture / le runbook que les URLs d’Authentik et des apps utilisateur sont les URLs Cloudflare (domaine derrière Cloudflare) et qu’il ne doit pas exister de moyen d’accès utilisateur qui contourne Cloudflare. |

En résumé : **trafic utilisateur = uniquement via Cloudflare** (Tunnel + proxy) ; pas d’accès direct à l’origine pour les utilisateurs finaux.

---

## 4. Synthèse

| Décision | Résumé |
|----------|--------|
| **Invitation-only** | Self-registration désactivée ; onboarding uniquement par lien d’invitation (UI ou API Authentik). Mise à jour de session-travail-authentik.md et PRD/architecture. |
| **Bonnes pratiques à traiter** | MFA admin, traçabilité/audit, runbook rotation des secrets, sécurisation webhook provisionnement. |
| **Trafic via Cloudflare** | Toutes les connexions utilisateur passent par Cloudflare (Tunnel) ; pas d’accès direct à l’origine ; règles WAF/config possibles pour renforcer. |

---

## 5. Prochaines actions

1. ~~Mettre à jour **session-travail-authentik.md** §6.1 (invitation-only) et §6.5 (flux première connexion).~~ ✅ Fait.
2. ~~Mettre à jour le **PRD** et l’**architecture** (Identity Design, Security) pour refléter invitation-only et trafic utilisateur via Cloudflare.~~ ✅ Fait.
3. ~~Dans les **epics/stories** Authentik : ajouter ou ajuster les critères pour désactiver la self-registration, configurer le flow d’enrollment par invitation, et documenter l’exposition uniquement via Cloudflare (et toute règle Cloudflare ajoutée).~~ ✅ Fait (epics-and-stories-homelab.md Epic 3.3, Stories 3.3.1 à 3.3.4).
