# Services Utilisateurs vs Techniques

## Séparation des services

### Services Utilisateurs (Publics)
Ce que tes utilisateurs voient et utilisent :

| Service | URL | Description |
|---------|-----|-------------|
| Homepage | `home.smadja.dev` | Dashboard d'accueil |
| Auth | `auth.smadja.dev` | Connexion SSO |
| Status | `status.smadja.dev` | État des services |
| Feedback | `feedback.smadja.dev` | Bug reports & features |
| *(futur)* Site vitrine | `smadja.dev` | Site web |
| *(futur)* DocuSeal | `sign.smadja.dev` | Signature documents |

### Services Techniques (Internes)
Réservés aux admins, invisibles pour les utilisateurs :

| Service | URL | Accès |
|---------|-----|-------|
| Proxmox | `proxmox.smadja.dev` | Twingate only |
| ArgoCD | `argocd.smadja.dev` | Cloudflare Access |
| Grafana | `grafana.smadja.dev` | Cloudflare Access |
| Prometheus | `prometheus.smadja.dev` | Cloudflare Access |
| Alertmanager | `alerts.smadja.dev` | Cloudflare Access |

## Configuration Uptime Kuma

### Status Page Publique (pour utilisateurs)
Créer une status page avec **uniquement** :
- ✅ Homepage
- ✅ Auth (Keycloak)
- ✅ Feedback
- ✅ Futurs services utilisateurs

### Monitoring Interne (pour admin)
Tous les services, mais **pas exposés** sur la status page publique.

## Configuration Fider

### Catégories suggérées
1. **Applications** - Feedback sur les apps utilisateurs
2. **Général** - Suggestions générales
3. **Nouveau service** - Demandes de nouveaux services

### Ce qui ne doit PAS apparaître
- Bugs d'infrastructure (Proxmox, K8s, etc.)
- Problèmes de monitoring
- Issues techniques → GitHub Issues à la place
