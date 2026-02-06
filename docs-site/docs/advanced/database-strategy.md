---
sidebar_position: 5
---

# Stratégie de Persistance des Données Authentik

## Problème

Les données Authentik (utilisateurs, applications, configurations) sont stockées dans PostgreSQL sur la même VM que les services. Si la VM est reconstruite, **toutes les données sont perdues**.

## Options Comparées

### Option 1 : Backup PostgreSQL + Restauration ⭐ **Recommandé**

**Avantages** :
- ✅ **Gratuit** (utilise OCI Object Storage déjà configuré)
- ✅ **Simple** : backup automatique quotidien
- ✅ **Rapide** : restauration en quelques minutes
- ✅ **Pas de dépendance externe** : tout reste dans OCI
- ✅ **Contrôle total** : tes données restent chez toi

**Inconvénients** :
- ⚠️ **RTO (Recovery Time Objective)** : ~5-10 minutes pour restaurer
- ⚠️ **RPO (Recovery Point Objective)** : jusqu'à 24h de perte (selon fréquence backup)

**Coût** : **0€** (Object Storage Always Free = 20GB)

---

### Option 2 : Oracle Autonomous Database ❌ **Non disponible**

**Limitations** :
- ❌ **Pas de PostgreSQL** : Oracle Autonomous DB supporte uniquement Oracle Database 19c/23ai
- ❌ Authentik nécessite PostgreSQL, pas compatible

**Verdict** : **Non applicable** pour ce cas d'usage

---

### Option 3 : Neon (PostgreSQL Serverless) ⚠️ **Alternative**

**Avantages** :
- ✅ **PostgreSQL natif** : compatible avec Authentik
- ✅ **Gratuit** : 0.5GB storage + 512MB RAM (tier gratuit)
- ✅ **Backup automatique** : point-in-time recovery
- ✅ **Haute disponibilité** : géré par Neon
- ✅ **Migration simple** : change juste la connection string

**Inconvénients** :
- ⚠️ **Dépendance externe** : données hors OCI
- ⚠️ **Limite gratuite** : 0.5GB peut être insuffisant à long terme
- ⚠️ **Latence** : connexion depuis OCI vers Neon (peut être plus lent)
- ⚠️ **Vendor lock-in** : migration vers autre provider plus complexe

**Coût** : **0€** (tier gratuit), puis ~$19/mois si upgrade

---

### Option 4 : PostgreSQL sur Volume OCI Persistant ⭐⭐ **Meilleur compromis**

**Avantages** :
- ✅ **Gratuit** : utilise Block Volume Always Free (200GB)
- ✅ **Persistant** : volume séparé de la VM
- ✅ **Rapide** : même région, latence minimale
- ✅ **Pas de dépendance externe** : tout dans OCI
- ✅ **Backup automatique** : snapshots OCI

**Inconvénients** :
- ⚠️ **Complexité** : nécessite configuration Terraform supplémentaire
- ⚠️ **RTO** : ~5 minutes pour attacher le volume à une nouvelle VM

**Coût** : **0€** (Block Volume Always Free = 200GB)

---

## Recommandation : Approche Hybride

### Phase 1 : Backup Automatique (Immédiat) ⭐

**Mise en place** :
1. Backup quotidien vers OCI Object Storage
2. Script de restauration automatisé
3. Monitoring des backups

**Avantages** :
- ✅ **Gratuit**
- ✅ **Rapide à mettre en place** (~1h)
- ✅ **RPO acceptable** : 24h max

**RTO** : ~10 minutes (restauration + redémarrage services)

---

### Phase 2 : Volume Persistant (Court terme) ⭐⭐

**Mise en place** :
1. Créer un Block Volume OCI dédié pour PostgreSQL
2. Migrer les données vers le volume
3. Attacher le volume à la VM

**Avantages** :
- ✅ **Gratuit** (Always Free)
- ✅ **RPO = 0** : pas de perte de données si VM reconstruite
- ✅ **RTO réduit** : ~5 minutes (attacher volume)

**RTO** : ~5 minutes

---

### Phase 3 : Neon (Si besoin de HA) ⚠️

**Seulement si** :
- Tu as besoin de haute disponibilité
- Le volume persistant ne suffit pas
- Tu acceptes la dépendance externe

---

## Plan d'Implémentation Recommandé

### Étape 1 : Backup Automatique (Cette semaine)

```bash
# Script de backup quotidien vers OCI Object Storage
# À ajouter dans le workflow CI ou cron sur la VM
```

**Bénéfices** :
- ✅ Protection immédiate contre perte de données
- ✅ Récupération possible même si volume corrompu
- ✅ Historique des backups

---

### Étape 2 : Volume Persistant (Semaine prochaine)

**Terraform** :
```hcl
# Créer un Block Volume dédié pour PostgreSQL
resource "oci_core_volume" "postgres_data" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "homelab-postgres-data"
  size_in_gbs         = 50  # 50GB suffit largement pour Authentik + Omni
  vpus_per_gb         = 10  # Balanced performance (free tier)
}
```

**Migration** :
1. Créer le volume
2. Attacher à la VM
3. Migrer les données PostgreSQL
4. Mettre à jour docker-compose.yml

**Bénéfices** :
- ✅ Données persistantes même si VM détruite
- ✅ RTO minimal
- ✅ RPO = 0

---

## Comparaison Finale

| Critère | Backup OCI | Volume Persistant | Neon |
|---------|------------|-------------------|------|
| **Coût** | 0€ | 0€ | 0€ (puis ~19€/mois) |
| **RTO** | ~10 min | ~5 min | ~1 min |
| **RPO** | 24h max | 0 | 0 |
| **Complexité** | Faible | Moyenne | Faible |
| **Dépendance** | Aucune | Aucune | Externe |
| **Latence** | N/A | Minimale | Variable |
| **Recommandation** | ⭐ Phase 1 | ⭐⭐ Phase 2 | ⚠️ Si besoin HA |

---

## Conclusion

**Recommandation finale** : **Backup automatique + Volume persistant**

1. **Court terme** : Mettre en place les backups automatiques (protection immédiate)
2. **Moyen terme** : Migrer vers un volume persistant (RPO=0, RTO minimal)
3. **Long terme** : Évaluer Neon seulement si besoin de haute disponibilité

Cette approche offre le meilleur compromis entre simplicité, coût, et protection des données.
