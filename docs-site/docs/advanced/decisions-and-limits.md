---
sidebar_position: 2
---

# Décisions, features et limites

Ce document garde une trace de la **philosophie**, des **choix techniques** (features utilisées par brique) et des **limites** que tu te fixes (ressources serveur, free tiers). Il ne décrit pas les setup service par service.

---

## Philosophie

1. **GitOps** : Tout est dans Git, déployé automatiquement (ArgoCD, Terraform en CI).
2. **Zero Trust** : Pas de ports ouverts ; accès via Cloudflare Tunnel et Twingate.
3. **Coût minimal** : Utilisation des free tiers (OCI, Cloudflare) ; pas d’activation de services payants sans décision explicite.
4. **Résilience** : Backups automatiques (Velero, ZFS), monitoring proactif (Prometheus, Alertmanager).

---

## Gestion du state Terraform

| Principe | Choix homelab |
|----------|----------------|
| **Backend distant** | OCI : bucket `homelab-tfstate` (backend `oci`). ~~Cloudflare / Proxmox : TFstate.dev (HTTP)~~ → Migré vers OCI Object Storage. |
| **Locking** | OCI : verrouillage natif. CI : `concurrency` par workflow (une run Terraform à la fois par stack). |
| **Isolation** | Un state par stack : `terraform/oracle-cloud`, `terraform/cloudflare`, `terraform/proxmox`. Pas d’état partagé entre stacks. |
| **Secrets dans le state** | Variables `sensitive = true` ; pas de credentials en clair dans tfvars committés. |
| **Backups** | Versioning activé sur le bucket OCI ; rollback possible via Console ou `terraform state push`. |

**Référence** : [Terraform Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/configuration), [Backend oci](https://developer.hashicorp.com/terraform/language/backend/oci).

---

## CI/CD

| Brique | Feature utilisée |
|--------|-------------------|
| **Terraform** | GitHub Actions : `terraform-oci`, `terraform-cloudflare`. Plan sur PR/develop, Apply sur main (environment production). Backend et secrets injectés par la CI. |
| **Kubernetes** | ArgoCD : sync depuis Git (app-of-apps). Pas de `kubectl apply` manuel pour les apps gérées par ArgoCD. |
| **Auth CI OCI** | Session token (court terme) au lieu de clé API longue durée. Script `./scripts/oci-session-auth-to-gh.sh` ; token à régénérer quand expiré (défaut 60 min). |
| **Secrets** | GitHub Secrets pour la CI. Optionnel : OCI Vault (créé par Terraform) pour centraliser ; contenu géré via variables sensibles ou CI. |

**Contraintes** : Ne pas lancer deux `terraform apply` simultanés sur la même stack ; utiliser les environnements GitHub (development / production) pour le flux.

---

## Secrets

- **CI** : GitHub Secrets (CLOUDFLARE_API_TOKEN, OCI_*, etc.). ~~TFSTATE_DEV_TOKEN~~ (déprécié, backend utilise OCI Object Storage). Recréation : voir [Rotate secrets](./../runbooks/rotate-secrets.md) et [.github/DEPLOYMENTS.md](https://github.com/SmadjaPaul/homelab/blob/main/.github/DEPLOYMENTS.md) à la racine du dépôt.
- **Kubernetes** : SOPS + Age pour les secrets chiffrés en Git ; External Secrets (optionnel) pour synchroniser depuis un vault.
- **Pas de secrets en clair** dans le repo (tfvars, YAML non chiffrés).

---

## Limites free tier et ressources

### Oracle Cloud (Always Free)

| Ressource | Limite | Usage homelab |
|-----------|--------|----------------|
| **Compute ARM (A1)** | 4 OCPUs, 24 GB RAM | oci-mgmt (1 OCPU, 6 GB), oci-node-1 (2 OCPU, 12 GB), oci-node-2 (1 OCPU, 6 GB) → 4 OCPU, 24 GB ✅ |
| **Object Storage** | 20 GB | Velero ~10 GB ; reste pour autre usage. |
| **Block Volume** | 200 GB total | À répartir entre VMs. |
| **Outbound Data** | 10 TB/mois | Suffisant pour homelab. |

**Contrainte** : Ne pas activer de services payants (ex. shapes non Always Free, Load Balancer payant) sans décision explicite. Budget alert à 1 € configuré (Terraform).

### Cloudflare

| Élément | Limite free | Note |
|---------|-------------|------|
| **DNS, CDN, SSL, DDoS** | Illimité | Utiliser le tunnel, pas d’IP exposée. |
| **Cloudflare Tunnel** | Illimité | Accès aux services sans ouvrir de ports. |
| **WAF custom rules** | 5 règles | Suffisant pour homelab. |
| **Cloudflare Access** | 50 users | Suffisant. |

**Contrainte** : Ne pas activer Argo Smart Routing, Load Balancing payant, Workers payants, etc. Rester sur le plan Free.

### Ressources serveur (Proxmox / local)

| Élément | Valeur | Note |
|---------|--------|------|
| **Proxmox host** | 64 GB RAM, 8 cores | Hyperviseur. |
| **talos-dev** | 4 GB RAM | Cluster DEV. |
| **talos-prod** | 16 GB RAM | Cluster PROD. |

Les limites exactes (CPU, RAM, disque) par VM sont définies dans Terraform ; ne pas dépasser les capacités du host.

---

## Résumé des contraintes volontaires

1. **Coût** : Rester dans les free tiers OCI et Cloudflare ; pas de dépense récurrente sans décision.
2. **State Terraform** : Toujours remote + locking ; pas d’édition manuelle du state.
3. **CI** : Une run Terraform à la fois par stack ; secrets uniquement via GitHub (et optionnellement OCI Vault).
4. **Ressources** : Rester dans les quotas OCI (4 OCPU, 24 GB, 20 GB Object Storage) et dans les capacités Proxmox.
