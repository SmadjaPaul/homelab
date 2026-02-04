# Audit de sécurité — OCI Management Stack

**Date** : 2026-02-04  
**Objectif** : Vérifier qu'aucun port n'est ouvert sur Internet, tout passe par Cloudflare Tunnel.

---

## ✅ Vérifications effectuées

### 1. OCI Security Lists (`terraform/oracle-cloud/network.tf`)

| Port | Source | Statut | Commentaire |
|------|--------|--------|-------------|
| **80** | `0.0.0.0/0` | ❌ **FERMÉ** | Conditionnel (`allow_public_http_https = false` par défaut) |
| **443** | `0.0.0.0/0` | ❌ **FERMÉ** | Conditionnel (`allow_public_http_https = false` par défaut) |
| **22** | Admin IPs + GitHub Actions | ✅ **RESTREINT** | Seulement depuis whitelist (ou `allow_ssh_from_anywhere` si true) |
| **ICMP** | `0.0.0.0/0` | ⚠️ **OUVERT** | Type 3 code 4 (Path MTU Discovery uniquement) |

**Résultat** : ✅ Aucun port TCP/UDP ouvert publiquement. SSH restreint aux IPs autorisées.

---

### 2. UFW Firewall (`terraform/oracle-cloud/compute.tf`)

- **SSH (22)** : ✅ Toujours autorisé
- **80/443** : ❌ **FERMÉ** (seulement si `allow_public_http_https = true`, false par défaut)
- **VCN interne (10.0.0.0/16)** : ✅ Autorisé (trafic inter-VM)

**Résultat** : ✅ UFW bloque 80/443 par défaut.

---

### 3. Docker Compose (`docker/oci-mgmt/docker-compose.yml`)

| Service | Port exposé | Binding | Statut |
|---------|-------------|---------|--------|
| **Traefik** | 8080 | `127.0.0.1:8080:8080` | ✅ **localhost uniquement** |
| **Authentik** | — | Aucun | ✅ Réseau Docker uniquement |
| **Omni** | — | Aucun | ✅ Réseau Docker uniquement |
| **Outpost** | — | Aucun | ✅ Réseau Docker uniquement |
| **PostgreSQL** | — | Aucun | ✅ Réseau Docker uniquement |
| **Redis** | — | Aucun | ✅ Réseau Docker uniquement |
| **cloudflared** | — | `network_mode: host` | ✅ Pas de ports exposés |

**Résultat** : ✅ Seul Traefik expose un port, et uniquement sur localhost (127.0.0.1).

---

### 4. Cloudflare Tunnel (`terraform/cloudflare/tunnel.tf`)

- **auth.smadja.dev** → `http://localhost:8080` (Traefik)
- **omni.smadja.dev** → `http://localhost:8080` (Traefik)

**Résultat** : ✅ Le tunnel envoie tout vers Traefik sur localhost, pas d'exposition directe.

---

## 🔒 Conclusion

**Aucun port n'est ouvert sur Internet** :

- ✅ Pas de 80/443 ouverts (Security List + UFW)
- ✅ SSH restreint aux IPs autorisées
- ✅ Services Docker accessibles uniquement via Traefik (localhost)
- ✅ Traefik accessible uniquement depuis cloudflared (localhost)
- ✅ cloudflared se connecte **outbound** à Cloudflare (pas de port exposé)

**Architecture Zero Trust** : Tout le trafic passe par Cloudflare Tunnel (chiffré, authentifié si configuré).

---

## ⚠️ Points d'attention

1. **`allow_public_http_https`** : Vérifier dans `terraform.tfvars` qu'il est à `false` (ou absent = défaut).
2. **`allow_ssh_from_anywhere`** : Vérifier qu'il est à `false` sauf pour débloquer temporairement la CI.
3. **Admin IPs** : Configurer `admin_allowed_cidrs` dans `terraform.tfvars` avec ton IP publique (format `/32`).

---

## 🧪 Tests de sécurité

Voir `_bmad-output/implementation-artifacts/test-instructions-oci-mgmt.md` pour les instructions de test.
