---
sidebar_position: 6
---

# Améliorations architecture Cloudflare + Authentik

Ce document s’appuie sur la [doc Cloudflare Access (JWT, Service Tokens)](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/application-token/), [Consume JWT](https://developers.cloudflare.com/learning-paths/clientless-access/migrate-applications/consume-jwt/) et [API Shield JWT](https://developers.cloudflare.com/api-shield/security/jwt-validation/), et sur des patterns type [webhook CI/CD derrière tunnel](https://blog.tymscar.com/posts/privategithubcicd/).

## 1. Ce qui peut poser problème aujourd’hui

### Double authentification (services “internal”)

Pour les services avec **Cloudflare Access** (grafana, argocd, proxmox, omni, etc.) :

- L’utilisateur se connecte une première fois à **Cloudflare Access** (email / IdP).
- Puis il arrive sur l’app (Grafana, Omni, etc.) qui peut avoir **Authentik Forward Auth** ou un autre login.

Résultat : deux logins pour une même session.
Comme décrit dans [Consume JWT](https://developers.cloudflare.com/learning-paths/clientless-access/migrate-applications/consume-jwt/), l’idéal est **une seule porte d’entrée** : soit Cloudflare, soit l’app, pas les deux en série.

### CI qui appelle l’API Authentik

- La CI (GitHub Actions) appelle `https://auth.smadja.dev` (API Authentik).
- Le trafic passe par Cloudflare → tunnel → Traefik → Authentik.
- Cloudflare peut renvoyer “Just a moment…” (bot/challenge) et bloquer la CI.

Tu as déjà des contournements (règle WAF, AUTHENTIK_TOKEN), mais on peut structurer ça proprement.

---

## 2. Piste A : Un seul gate – faire consommer le JWT Cloudflare

Idée : [Cloudflare Access émet un JWT](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/application-token/) (cookie `CF_Authorization`) après login. Les apps peuvent **valider ce JWT** au lieu de refaire un login.

- **Option A1 – Cloudflare comme seul gate**
  - Tu gardes Cloudflare Access sur les services “internal”.
  - Tu **désactives** Forward Auth Authentik (ou login propre) pour ces apps.
  - Les apps lisent le JWT Cloudflare (cookie ou header passé par un Worker) et font confiance à Cloudflare pour l’identité.
  - Une seule auth : Cloudflare Access.

- **Option A2 – Authentik comme seul gate**
  - Tu enlèves Cloudflare Access pour les services que tu veux protéger avec Authentik.
  - Tout passe par Traefik + Authentik (Forward Auth / proxy auth).
  - Une seule auth : Authentik.

Recommandation homelab : **A2** est souvent plus simple (tu centralises tout dans Authentik). **A1** est utile si tu veux tout gérer côté Cloudflare (Identity, device posture, etc.).

---

## 3. Piste B : CI qui appelle l’API Authentik – deux approches propres

### B1. Cloudflare Access **Service Token** (machine-to-machine)

[Cloudflare Access propose des Service Tokens](https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/) pour l’accès machine-to-machine.

- Tu crées une **Access Application** dédiée à l’API Authentik (ex. `api-auth.smadja.dev` ou une règle sur `auth.smadja.dev` avec path `/api/v3/` et `/application/o/`).
- Tu crées un **Service Token** (Client ID + Client Secret).
- En CI, chaque requête vers cette URL envoie :
  - `CF-Access-Client-Id: <client_id>`
  - `CF-Access-Client-Secret: <client_secret>`
- Cloudflare considère la requête comme “authentifiée” → pas de challenge “Just a moment…”.
- L’origin (Authentik) reçoit la requête et doit toujours être authentifié avec son propre mécanisme (token API Authentik dans `Authorization: Bearer ...`).

En résumé : **Service Token = passer la porte Cloudflare**, **AUTHENTIK_TOKEN = s’authentifier auprès d’Authentik**. Les deux ensemble donnent un flux clair et évitent de dépendre uniquement des règles WAF / désactivation du bot.

### B2. Pattern **webhook derrière le tunnel** (style [Tymscar](https://blog.tymscar.com/posts/privategithubcicd/))

- La CI **n’appelle jamais** l’API Authentik depuis internet.
- Tu exposes un **webhook** derrière le tunnel (ex. `webhook.smadja.dev`), protégé par un secret (query param ou header).
- La CI envoie une requête POST au webhook du type : “déploie JWKS” ou “run terraform authentik”.
- Le **webhook tourne dans ton LAN** (ou sur la VM OCI mgmt) et :
  - soit appelle l’API Authentik en interne (sans passer par Cloudflare),
  - soit lance Terraform / scripts qui parlent à Authentik en local.

Avantages : l’API Authentik n’a pas besoin d’être joignable depuis internet ; la CI ne gère pas directement les tokens Authentik. Inconvénient : il faut maintenir un service webhook et le sécuriser (secret, liste d’actions autorisées).

---

## 4. Où utiliser quoi

| Besoin | Approche recommandée |
|--------|----------------------|
| Éviter double auth (Access + app) | Choisir un seul gate : soit Cloudflare (apps consomment le [JWT Cloudflare](https://developers.cloudflare.com/learning-paths/clientless-access/migrate-applications/consume-jwt/)), soit Authentik (retirer Access sur ces apps). |
| La CI doit appeler l’API Authentik | **Court terme** : garder AUTHENTIK_TOKEN + règle WAF / désactivation bot si besoin. **Plus propre** : B1 (Service Token) pour passer Cloudflare + AUTHENTIK_TOKEN pour Authentik. |
| Ne pas exposer l’API Authentik sur internet | B2 (webhook derrière tunnel) : la CI déclenche un job interne qui appelle Authentik depuis le LAN. |
| Valider des JWTs (ex. Authentik) à l’entrée de tes APIs | [API Shield – JWT validation](https://developers.cloudflare.com/api-shield/security/jwt-validation/) : tu déclares le JWKS d’Authentik et Cloudflare rejette les requêtes avec JWT invalide/expiré. Utile si tu exposes des APIs qui attendent un Bearer JWT. |

---

## 5. Actions concrètes suggérées

1. **Clarifier la stratégie “un seul gate”**
   - Soit tout derrière Cloudflare Access et les apps consomment le JWT Cloudflare.
   - Soit tout derrière Authentik (Forward Auth) et tu retires Access sur les apps concernées pour éviter la double auth.

2. **CI → Authentik**
   - Soit mettre en place un **Service Token** Cloudflare (B1) pour les requêtes CI vers `auth.smadja.dev` (paths API) et garder AUTHENTIK_TOKEN pour l’origin.
   - Soit introduire un **webhook** (B2) et ne plus appeler l’API Authentik depuis internet.

3. **Optionnel**
   - Si tu exposes des APIs qui reçoivent un JWT (ex. issu d’Authentik), configurer la [JWT validation API Shield](https://developers.cloudflare.com/api-shield/security/jwt-validation/) sur les hostnames/paths concernés.

En résumé : le “truc qui ne va pas” peut être la **double auth** (Access + app) et le fait que **la CI passe par la même porte que les bots** (challenge). Les deux pistes ci-dessus (un seul gate + Service Token ou webhook) alignent ton setup avec les bonnes pratiques Cloudflare et simplifient l’expérience utilisateur et la CI.

---

## 6. Authentik derrière le tunnel : ne jamais l’exposer directement

Tu veux que les utilisateurs passent **vraiment** par Authentik. Il faut aussi que **Authentik lui-même** reste protégé par Cloudflare. Les deux vont ensemble.

### Rôle du tunnel

- **Avec le tunnel** : tout le trafic vers `auth.smadja.dev` (et les autres hostnames) passe par **Cloudflare** (edge) puis par le **tunnel** jusqu’à ton origine (Traefik → Authentik). Donc :
  - Cloudflare applique **DDoS, WAF, Bot Fight Mode**, etc. **avant** que la requête n’atteigne ton infra.
  - Aucun port de ton réseau n’est ouvert sur internet ; le tunnel est le seul point d’entrée.

- **Sans le tunnel** (exposer Authentik “directement”) : par exemple un enregistrement DNS en A/AAAA vers l’IP de ta VM, ou un reverse proxy exposé sur le net. Dans ce cas, le trafic n’irait **pas** par Cloudflare → tu perds la protection edge (DDoS, WAF, etc.) et tu exposes des IP/ports. **À ne pas faire.**

### Ce qu’on recommande

- **Authentik reste uniquement joignable via le tunnel** : `auth.smadja.dev` = CNAME vers le tunnel (comme aujourd’hui). Aucune exposition directe (pas de A/AAAA vers l’origin, pas de port ouvert sur internet pour Authentik).
- **Pas de Cloudflare Access sur auth.smadja.dev** : la seule “porte” identité pour la page de login Authentik, c’est **Authentik** (login / MFA). Cloudflare ne fait que proxy + protection (WAF, DDoS) ; il ne fait pas une deuxième couche de login.
- Pour les autres apps “internal” (omni, grafana, etc.) : même logique — elles restent **derrière le tunnel** (donc protégées par Cloudflare), et on retire Cloudflare Access pour n’avoir qu’**Authentik** comme gate. Les utilisateurs passent bien par Authentik, et le tunnel assure la protection réseau.

En résumé : **tunnel = protection Cloudflare pour tout le trafic (y compris Authentik)** ; **Authentik = seule porte d’authentification pour les utilisateurs**. On n’expose jamais Authentik sans le tunnel.
