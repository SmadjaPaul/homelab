---
sidebar_position: 12
---

# Authentik + Cloudflare : comparaison avec le guide « authentikate-your-cloudflared »

Ce document compare ta configuration (Terraform + scripts) au guide [authentikate-your-cloudflared](https://github.com/eclecticbouquet/authentikate-your-cloudflared) et indique ce qui est déjà en place et ce qu’il peut être utile d’ajouter.

## Ce que tu as déjà (et le guide aussi)

| Élément | Guide (manuel) | Toi (Terraform / setup) |
|--------|----------------|--------------------------|
| Authentik en Docker | ✅ | ✅ `docker/oci-mgmt` |
| Tunnel Cloudflare (cloudflared) | ✅ | ✅ Terraform tunnel + déploiement |
| Exposition d’Authentik (auth.xxx) | ✅ | ✅ `auth.smadja.dev` |
| Provider OAuth2/OIDC pour Cloudflare (redirect callback) | ✅ manuel | ✅ `terraform/authentik/cloudflare-access-oidc.tf` |
| IdP OpenID Connect dans Zero Trust | ✅ manuel | ✅ `terraform/cloudflare/modules/access` |
| Policy « autoriser les utilisateurs Authentik » | ✅ (Login Methods) | ✅ Policy « Allow Authentik users » (everyone) |
| Une seule méthode de login = pas de choix IdP | ✅ (option UI) | ✅ `allowed_idps = [authentik]` (un seul IdP) |

En résumé : **le flux Authentik ↔ Cloudflare Access est déjà couvert par ton Terraform** (provider OIDC + IdP + policies). Le guide n’apporte pas de « feature » en plus sur ce point.

## Ce que le guide fait en plus (et qui peut t’intéresser)

### 1. Certificat Origin Cloudflare dans Authentik

**Guide :** Créer un certificat « Origin Server » dans Cloudflare, puis l’importer dans Authentik (System → Certificates) et l’utiliser comme certificat de signing / TLS côté Authentik.

**Intérêt :** En mode SSL **Full (strict)** sur Cloudflare, l’origine doit présenter un certificat valide. Le certificat Origin Cloudflare est fait pour ça (valide entre ton origine et Cloudflare). Aujourd’hui tu utilises le certificat auto-signé Authentik (`authentik Self-signed Certificate`) pour le provider OIDC ; si tu n’as pas d’erreur SSL, tu peux rester comme ça. Si tu veux tout aligner avec Cloudflare, tu peux ajouter le certificat Origin dans Authentik et l’utiliser pour le provider (ou pour TLS si tu sers Authentik en HTTPS avec ce cert).

**À faire (optionnel) :**
- Créer le certificat dans Cloudflare (Dashboard → SSL/TLS → Origin Server).
- Dans Authentik : System → Certificates → Create, coller certificat + clé privée.
- Optionnel en Terraform : si le provider Authentik permet de gérer un `authentik_certificate_key_pair` à partir d’un certificat existant, tu pourrais le référencer ; sinon, rester en manuel pour ce certificat.

### 2. MFA (TOTP) pour le compte admin Authentik

**Guide :** Activer un appareil TOTP (Settings → MFA Devices) pour le compte `akadmin`.

**Intérêt :** Très recommandé pour le compte admin (Authentik est la porte d’entrée de ton SSO).

**À faire :** Uniquement dans l’UI Authentik (Settings → MFA Devices → Enroll → TOTP). Rien à changer dans le Terraform. Tu peux ajouter une ligne dans ta doc « configuration initiale » pour rappeler de le faire.

### 3. Bypass des requêtes OPTIONS (CORS preflight)

**Guide :** « Bypass options requests to origin » sur l’application Access.

**Intérêt :** Éviter que les requêtes OPTIONS (preflight CORS) soient bloquées ou forcent une page de login.

**À faire :** Si le provider Terraform Cloudflare expose un paramètre du type `options_preflight_bypass` (ou équivalent) sur `cloudflare_zero_trust_access_application`, l’activer en Terraform. Sinon, le faire une fois dans l’UI (Access → Application → …).

### 4. « Skip identity provider selection » quand un seul IdP

**Guide :** « Allow users to skip identity provider selection when only one login method is available ».

**Intérêt :** UX : pas d’écran de choix, envoi direct vers Authentik.

**Toi :** Avec `allowed_idps = [authentik]` (un seul IdP), Cloudflare envoie déjà vers Authentik. Le comportement peut déjà être « skip » selon la config Zero Trust ; si ce n’est pas le cas, activer cette option dans l’UI (Settings de l’application Access). À vérifier côté API/Terraform si le paramètre existe.

### 5. Règles WAF (ex. géo)

**Guide :** Exemple de règle WAF (ex. bloquer tout ce qui n’est pas US).

**Intérêt :** Renforcer la sécurité au bord Cloudflare (limiter par pays, etc.).

**À faire :** En plus de ton Terraform actuel : règles WAF dans Cloudflare (Dashboard ou API/Terraform si tu gères le WAF en code). Pas lié à Authentik directement.

### 6. Monitoring / logs

**Guide :** Consulter les events Authentik et les logs Access.

**Intérêt :** Dépannage et audit.

**À faire :** Authentik → Events ; Cloudflare Zero Trust → Access → Logs. Pas d’implémentation Terraform nécessaire, juste doc / procédure si tu veux.

## Recommandations concrètes

- **Déjà bien en place :**
  - Intégration Authentik ↔ Cloudflare Access (OIDC + IdP + policies) en Terraform.
  - Pas besoin de « ré-implémenter » le guide pour cette partie.

- **À ajouter si tu veux coller au guide et bonifier :**
  1. **MFA admin** : rappel dans la doc (ex. `authentik-initial-setup.md`) de configurer TOTP pour l’admin.
  2. **Bypass OPTIONS** : activer dans Terraform (si le provider le permet) ou une fois dans l’UI.
  3. **Certificat Origin** : optionnel, seulement si tu vises Full (strict) ou une config TLS plus stricte entre Cloudflare et Authentik.
  4. **WAF / géo** : si tu veux des règles par pays, les ajouter côté Cloudflare (hors scope Authentik).

En résumé : le guide ne t’apporte pas de fonctionnalité Authentik↔Cloudflare en plus de ce que tu as déjà ; il justifie surtout d’ajouter **MFA admin**, **bypass OPTIONS** (et éventuellement **certificat Origin** et **WAF**) si tu veux être aligné avec ses bonnes pratiques.
