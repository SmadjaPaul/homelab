# Sécurité OpenClaw (gateway)

Le gateway OpenClaw est exposé derrière **Traefik** et **Authentik Forward Auth** (openclaw.smadja.dev). En plus de l’auth par Authentik, un **token gateway** limite l’accès aux clients (CLI, apps) qui appellent l’API.

## Token gateway

- Définir **`OPENCLAW_GATEWAY_TOKEN`** dans le `.env` (ou via Ansible / OCI Vault en CI).
- Génération : `openssl rand -hex 32`
- Les clients (CLI OpenClaw, intégrations) doivent envoyer ce token (header ou param) pour être acceptés par le gateway.

## Trusted proxies

Le fichier **`openclaw/security-defaults.json`** définit `trustedProxies` pour que le gateway fasse confiance aux en-têtes `X-Forwarded-*` envoyés par Traefik (IP réelle, proto, host).

## Références

- [OpenClaw Configuration](https://clawdbot.online/configuration/)
- Stack : Traefik (Forward Auth) → Authentik outpost → OpenClaw gateway (port 18789)
