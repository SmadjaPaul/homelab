# Roadmap OCI-First : Finaliser OCI avant le local

**Date** : 2026-02-04  
**Stratégie** : Finaliser toute la configuration OCI avant de passer au serveur local pour sécuriser avant d'exposer le réseau local.

## Principe

1. **OCI d'abord** : Compléter Phase 3 (Oracle Cloud) avant Phase 1 (local)
2. **Sécurité avant exposition** : Tout doit être sécurisé sur OCI avant de connecter le local
3. **Zero Trust** : Cloudflare Tunnel + Twingate pour l'accès sécurisé

---

## Plan d'action OCI-First

### Étape 1 : Infrastructure OCI de base ✅

| Story | Status | Action |
|-------|--------|--------|
| **1.3.1** Provision OCI Management VM | ✅ Done | VM créée |
| **1.3.2** Deploy Omni Server | ✅ Done | Stack déployée via CI |
| **3.2.1** Provision OCI Compute (K8s nodes) | ⏳ Next | Créer les VMs K8s via Terraform |

### Étape 2 : Finaliser Omni sur OCI

| Story | Status | Action |
|-------|--------|--------|
| **1.3.3** Register CLOUD Cluster with Omni | ⏳ | Créer cluster dans Omni (via UI ou `omnictl`), enregistrer le cluster CLOUD |
| **1.3.4** Configure MachineClasses | ⏳ | Définir MachineClasses dans `omni/machine-classes/` |

**Note** : Pour CLOUD, créer le cluster dans l'UI Omni et télécharger l'image Oracle ; importer l'image dans OCI, définir `talos_image_id`, puis terraform apply. Les VMs s'enrôlent dans Omni au premier boot (voir [Zwindler](https://blog.zwindler.fr/2025/01/04/sideros-omni-talos-oracle-cloud/)). Pour DEV (Proxmox), ajouter la config Omni dans les YAML Talos et appliquer avec talosctl.

### Étape 3 : Cluster Kubernetes CLOUD sur OCI

| Story | Status | Action |
|-------|--------|--------|
| **3.2.1** Provision OCI Compute | ⏳ | `terraform apply` dans `terraform/oracle-cloud/` pour créer les VMs K8s |
| **3.2.2** Bootstrap CLOUD Cluster | ⏳ | Bootstrapper le cluster Talos sur OCI, enregistrer dans Omni |

### Étape 4 : Sécurité et accès (Cloudflare Tunnel + Authentik)

| Story | Status | Action |
|-------|--------|--------|
| **3.4.1** Deploy Cloudflare Tunnel | ⏳ | Configurer le tunnel pour Omni/Authentik (déjà déployé sur oci-mgmt, configurer les routes) |
| **3.3.1** Deploy Authentik | ✅ | Déjà déployé dans stack oci-mgmt |
| **3.3.2** Configure oauth2-proxy | ⏳ | Déployer oauth2-proxy pour protéger les services |
| **3.3.3** Configure Authentik Applications | ⏳ | Configurer les applications/providers dans Terraform |

### Étape 5 : Services critiques sur CLOUD

| Story | Status | Action |
|-------|--------|--------|
| **4.1.1** Deploy Nextcloud | ⏳ | Sur cluster CLOUD, avec Authentik SSO |
| **4.1.2** Deploy Vaultwarden | ⏳ | Sur cluster CLOUD, avec Authentik SSO |
| **4.1.3** Deploy Baïkal | ⏳ | Sur cluster CLOUD, avec Authentik SSO |

### Étape 6 : Une fois OCI sécurisé → Connecter le local

| Story | Status | Action |
|-------|--------|--------|
| **3.4.2** Deploy Twingate Connector | ⏳ | Sur cluster CLOUD pour accès sécurisé au réseau local |
| **1.2.2** Bootstrap DEV Cluster | ⏳ | Sur Proxmox local (maintenant sécurisé) |
| **1.3.3** Register DEV Cluster | ⏳ | Enregistrer le cluster DEV local dans Omni |

---

## Ordre d'exécution recommandé

### Phase A : Infrastructure OCI (Sécurité de base)

1. ✅ **1.3.1** + **1.3.2** : VM OCI + Omni (fait)
2. ⏳ **3.2.1** : Créer VMs K8s sur OCI via Terraform
3. ⏳ **3.2.2** : Bootstrapper cluster CLOUD Talos
4. ⏳ **1.3.3** : Enregistrer cluster CLOUD dans Omni
5. ⏳ **1.3.4** : Configurer MachineClasses

### Phase B : Sécurité et accès (Zero Trust)

6. ⏳ **3.4.1** : Finaliser Cloudflare Tunnel (routes pour Omni/Authentik)
7. ⏳ **3.3.2** : Déployer oauth2-proxy
8. ⏳ **3.3.3** : Configurer Authentik (applications, providers)
9. ⏳ **3.3.4** : Configurer Authentik webhooks (optionnel)

### Phase C : Services sur CLOUD (Validation)

10. ⏳ **4.1.1** : Nextcloud sur CLOUD
11. ⏳ **4.1.2** : Vaultwarden sur CLOUD
12. ⏳ **4.1.3** : Baïkal sur CLOUD

### Phase D : Connexion sécurisée au local

13. ⏳ **3.4.2** : Twingate Connector sur CLOUD (accès sécurisé au réseau local)
14. ⏳ **1.2.2** : Bootstrap DEV cluster sur Proxmox local
15. ⏳ **1.3.3** : Enregistrer DEV cluster local dans Omni (via Twingate)

---

## Stories à préparer en priorité (OCI)

### Prêtes pour développement

1. **3.2.1** Provision OCI Compute — Terraform prêt, juste à appliquer
2. **3.2.2** Bootstrap CLOUD Cluster — Configs Talos à créer
3. **3.4.1** Deploy Cloudflare Tunnel — Routes à configurer
4. **3.3.2** Configure oauth2-proxy — Manifest à créer
5. **3.3.3** Configure Authentik Applications — Terraform à finaliser

---

## Notes importantes

- **Omni** : Peut être finalisé manuellement (créer cluster dans UI) ou via `omnictl` si installé
- **Sécurité** : Cloudflare Tunnel + Authentik doivent être opérationnels avant de connecter le local
- **Twingate** : Nécessaire pour que CLOUD accède au réseau local (NFS, etc.)
- **Dépendances** : Phase 1 (local) peut attendre que Phase 3 (OCI) soit sécurisée

---

## Références

- [Epics & Stories](../planning-artifacts/epics-and-stories-homelab.md)
- [Implementation Progress](../planning-artifacts/implementation-progress.md)
- [Architecture](../planning-artifacts/architecture-proxmox-omni.md)
- Gestion des configs OCI : voir `docs-site/docs/guides/secrets-management.md` et `docs-site/docs/getting-started/secrets-setup.md`
