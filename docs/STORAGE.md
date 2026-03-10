# Stratégie de Stockage Homelab (V2)

Ce document définit la répartition du stockage pour le Homelab afin de maximiser les performances tout en respectant les limites de l'**Oracle Free Tier** (200 Go).

## 🌍 État de l'Infrastructure (Ground Truth)

*   **Noeuds** : 2 noeuds (2 OCPUs, 12 Go RAM chacun).
*   **Disques de démarrage (Boot Volumes)** : 2 x 50 Go = **100 Go** (Consommés).
*   **Quota Block Storage utilisé (Consolidé)** : **100 Go** (2 x 50 Go pour le cluster HA).
*   **Quota OCI Total** : **200 Go** (100% utilisé).

---

## 📊 Consolidation de la Base de Données (Shared HA)

Pour respecter la limite de **50 Go minimum par volume OCI**, nous avons consolidé toutes les bases de données applicatives dans un unique cluster **CloudNativePG** hautement disponible.

| Composant | Rôle | Type de Stockage | Taille | Raison |
| :--- | :--- | :--- | :--- | :--- |
| **homelab-db** | Cluster PostgreSQL Partagé | `oci-bv` (HA 2-nodes) | **2 x 50 Go** | HA Requise + Minimum OCI |
| **Applications** | DBs (Vaultwarden, Nextcloud, etc.) | - | - | Provisionnées dans `homelab-db` |
| **Redis** | Sessions & Cache | `local-path` | - | Performance I/O locale, éphémère |
| **Storage Box** | Données volumineuses | `hetzner-smb` | 1 To+ | Coût & Capacité |

---

## 🏗️ Stratégie Technique par Tier

### Tier 1 : Performance & Persistance (OCI Block Storage - `oci-bv`)
*   **Usage** : Bases de données PostgreSQL uniquement.
*   **Avantage** : Persistant, découplé du cycle de vie des noeuds, snapshots OCI possibles.
*   **Limite** : Ne jamais dépasser **100 Go** au total.

### Tier 2 : Performance Éphémère (Disque Local - `local-path`)
*   **Usage** : Redis, Caches d'applications, Temp files.
*   **Avantage** : Latence quasi nulle (I/O disque local).
*   **Risque** : Données perdues si le noeud est supprimé.

### Tier 3 : Capacité (Hetzner Storage Box - `hetzner-smb`)
*   **Usage** : Données volumineuses (Fichiers Nextcloud, Musique Navidrome, Archives Paperless).
*   **Avantage** : Coût très faible, capacité virtuellement illimitée.
*   **Inconvénient** : Latence réseau (car distant de Paris).

---

## 🛡️ Mesures de Protection
1.  **Validation Pulumi** : Le code de déploiement vérifie et bloque tout volume `oci-bv` qui ferait dépasser la barre des 100 Go.
2.  **Audit Quota** : Utiliser `pytest tests/dynamic/test_storage_quotas.py` pour vérifier la "vérité terrain" via l'API OCI.
