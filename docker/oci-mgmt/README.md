# OCI Management Stack

Stack de gestion déployé sur la VM OCI gratuite, exposé via **Cloudflare Tunnel** (Zero Trust).

## Architecture

```
Internet → Cloudflare Tunnel → cloudflared (host) → localhost:8080 (Traefik)
                                                                  │
                                    ┌─────────────────────────────┼─────────────────────────────┐
                                    ▼                             ▼                             ▼
                             auth.smadja.dev              omni.smadja.dev              (futurs services)
                             → Authentik:9000             → Forward Auth → Omni:8080   → routes à ajouter
```

**Point d’entrée unique** : le tunnel envoie tout le trafic (auth + omni) vers **Traefik** sur le port 8080. Traefik route par hostname et applique le Forward Auth Authentik pour Omni. Les autres hostnames du tunnel (Grafana, ArgoCD, etc.) pointent vers des services K8s et nécessitent un cloudflared dans le cluster ou un second tunnel.

## Services

| Service | Port / réseau | URL publique | Description |
|---------|----------------|--------------|-------------|
| **Traefik** | 8080 (host) | — | Reverse proxy unique (auth + omni + futures routes) |
| Authentik | 9000 (réseau) | auth.smadja.dev | SSO / Identity Provider |
| Authentik Outpost | 9000 (réseau) | — | Forward Auth pour Traefik (Omni + futures apps) |
| Omni | 8080 (réseau) | omni.smadja.dev | Talos Linux management (protégé par Forward Auth) |
| PostgreSQL | 5432 | - | Base de données (interne) |
| Redis | 6379 | - | Cache Authentik (interne) |

## Prérequis

1. **Cloudflare Tunnel** créé dans le dashboard Zero Trust
2. **DNS configuré** dans Cloudflare (CNAME vers le tunnel)
3. **Secrets** dans le fichier `.env`

## Déploiement

### 1. Créer le Tunnel Cloudflare

```bash
# Dans Cloudflare Dashboard > Zero Trust > Networks > Tunnels
# Créer un nouveau tunnel "homelab-oci-mgmt"
# Copier le token
```

### 2. Configurer les routes du Tunnel

Le tunnel envoie tout le trafic OCI mgmt vers **Traefik** (un seul port). Dans Cloudflare Zero Trust → Networks → Tunnels → [votre tunnel] → **Public Hostname** :

| Subdomain | Type | URL (Service) |
|-----------|------|----------------|
| auth.smadja.dev | HTTP | `localhost:8080` |
| omni.smadja.dev | HTTP | `localhost:8080` |

Traefik route par hostname. Si le tunnel est géré par Terraform (`terraform/cloudflare`), les routes sont dans `tunnel.tf`.

### 3. Configurer les variables d'environnement

```bash
# Sur la VM OCI
cd ~/homelab/oci-mgmt
cp .env.example .env

# Générer les secrets
POSTGRES_PASSWORD=$(openssl rand -base64 32)
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60)

# Éditer .env avec les valeurs
nano .env
```

### 4. Démarrer la stack

```bash
docker compose up -d
```

### 5. Accéder à Authentik (premier service à déployer)

1. Ouvrir https://auth.smadja.dev/if/flow/initial-setup/
2. Créer le compte admin
3. Ajouter ton utilisateur au groupe **admin** (Directory → Groups → admin)
4. **Forward Auth pour Omni** : l’application Omni et le provider (mode `forward_single`) sont dans Terraform (`terraform/authentik/applications_omni.tf`). Après `terraform apply` : Outposts → assigner le provider « omni-proxy » à l’outpost, copier le **token** → `.env` (`AUTHENTIK_OUTPOST_TOKEN`) puis redémarrer. Omni sera alors accessible via https://omni.smadja.dev après login Authentik (Traefik fait le Forward Auth vers l’outpost).

## Maintenance

```bash
# Voir les logs
docker compose logs -f

# Redémarrer un service
docker compose restart authentik-server

# Mise à jour
docker compose pull
docker compose up -d

# Backup PostgreSQL
docker compose exec postgres pg_dumpall -U homelab > backup.sql
```

## Sécurité

- **Aucun port exposé** directement sur Internet
- Tout le trafic passe par **Cloudflare Tunnel** (chiffré)
- **Cloudflare Access** peut être ajouté pour 2FA sur les services admin
- La VM a **fail2ban**, **UFW**, et les **mises à jour automatiques**

## Troubleshooting

### Le tunnel ne se connecte pas

```bash
# Vérifier les logs cloudflared
docker compose logs cloudflared

# Vérifier le token
echo $CLOUDFLARE_TUNNEL_TOKEN | wc -c  # Doit être > 100
```

### Authentik ne démarre pas

```bash
# Vérifier que PostgreSQL est prêt
docker compose logs postgres
docker compose exec postgres pg_isready -U homelab

# Vérifier les migrations
docker compose logs authentik-server
```

### Omni renvoie HTTP 500

1. **Logs Omni** : `docker compose logs omni` — erreurs de migration ou de connexion DB.
2. **Base Omni** : la DB `omni` est créée par `init-db/01-create-databases.sql`. Vérifier `OMNI_DB_URL` dans `.env` (user/host/db=omni) et que postgres est healthy.
3. **Redémarrage** : après la première création des DB, `docker compose restart omni` peut être nécessaire.
4. **Config Omni en IaC** : voir [omni/README.md](../../omni/README.md) (MachineClasses, clusters via omnictl).

### Services inaccessibles via le tunnel (502 Bad Gateway)

1. **Routes du tunnel** : auth et omni doivent pointer vers **localhost:8080** (Traefik). Vérifier dans Cloudflare Zero Trust ou dans `terraform/cloudflare/tunnel.tf`.
2. **Traefik à l’écoute** : sur la VM, `curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080` (Host: auth.smadja.dev) doit retourner 200 après démarrage.
3. **Logs** : `docker compose logs traefik`, `docker compose logs cloudflared`, `docker compose logs authentik-outpost-proxy`.

---

## Ajouter des services ou des redirects

Traefik est déjà le point d’entrée. Pour ajouter :

- **Une nouvelle app** (ex. Radarr, Grafana) : ajouter un routeur + service (et optionnellement le middleware `forward-auth-omni`) dans `traefik/dynamic/routes.yml`, puis ajouter le hostname dans le tunnel (Cloudflare ou Terraform) vers `localhost:8080`.
- **Un redirect externe** (ex. Comet → Real-Debrid) : ajouter un routeur avec un middleware **RedirectRegex** ou **Redirect** vers l’URL cible dans `traefik/dynamic/routes.yml`.

Voir `_bmad-output/implementation-artifacts/oci-mgmt-traefik-option.md` pour les exemples de redirects.
