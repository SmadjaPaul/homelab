# OCI Management Stack

Stack de gestion déployé sur la VM OCI gratuite, exposé via **Cloudflare Tunnel** (Zero Trust).

## Architecture

```
Internet → Cloudflare (WAF/DDoS) → Tunnel → cloudflared → Services internes
                                                            ├── Authentik (auth.smadja.dev)
                                                            └── Omni (omni.smadja.dev)
```

## Services

| Service | Port interne | URL publique | Description |
|---------|-------------|--------------|-------------|
| Authentik | 9000 | auth.smadja.dev | SSO / Identity Provider |
| Omni | 8080 | omni.smadja.dev | Talos Linux management |
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

Dans la configuration du tunnel, ajouter les routes :

| Subdomain | Service | URL |
|-----------|---------|-----|
| auth.smadja.dev | HTTP | http://authentik-server:9000 |
| omni.smadja.dev | HTTP | http://omni:8080 |

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

### 5. Accéder à Authentik

1. Ouvrir https://auth.smadja.dev/if/flow/initial-setup/
2. Créer le compte admin
3. Configurer les providers OAuth/SAML pour les autres services

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

### Services inaccessibles via le tunnel

1. Vérifier la configuration des routes dans Cloudflare Dashboard
2. Vérifier que le nom du service correspond (ex: `authentik-server`, pas `authentik`)
3. Tester localement : `docker compose exec cloudflared curl http://authentik-server:9000`
