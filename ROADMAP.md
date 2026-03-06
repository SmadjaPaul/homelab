# 🗺️ Roadmap Homelab

Ce document définit la vision à court, moyen et long terme de la plateforme Homelab, inspirée des revues d'architecture et du catalogue de services actuel.

## 🌟 Version 1.0 & 1.1 (✅ Terminées)

La V1.0 a établi les fondations sécurisées, l'infrastructure-as-code déclarative et l'identité unifiée.
La V1.1 a apporté le refactoring modulaire, des design patterns stricts (Adapter, Strategy) et une résilience Kubernetes accrue.

### Core Infrastructure & Sécurité (V1.0)
- [x] Déploiement Cluster OCI (OKE) via Pulumi.
- [x] Configuration centralisée des secrets via Doppler (Fail-Fast pre-flight).
- [x] Intégration *External Secrets Operator*.
- [x] Provisionnement du stockage (Hetzner Storage Box CSI, Oracle Free Tier S3).
- [x] Tunneling Zero-Trust Cloudflare (Aucun port entrant ouvert).

### Identité & Gestion (Automatisée)
- [x] Déploiement d'Authentik comme IdP centralisé.
- [x] Auto-provisionnement OIDC pour les applications protégées via `AppRegistry`.
- [x] Architecture "Data-Driven" stricte via `apps.yaml`.

### Suite de Tests (Zero-Modification Policy)
- [x] Suite Pytest couvrant les assertions Statiques, Unitaires et Dynamiques (Routage, Secrets, Connexion).
- [x] Intégration de schémas stricts Pydantic.

---

### Refactoring & Architecture Modulaire (V1.1)
- [x] **Strategy Pattern pour Helm** : Refactorisation de `generic.py` (`get_final_values()`) en utilisant des adaptateurs dédiés (`StandardAdapter`, `AuthentikAdapter`, `AppTemplateAdapter`) pour supprimer le code "spaghetti".
- [x] **Découplage des Registries** : Scission de `registry.py` en plusieurs entités à responsabilité unique : `AuthentikRegistry`, `KubernetesRegistry` et `StorageRegistry`.
- [x] **Modularisation du DNS** : Extraction de la configuration DNS Migadu/Cloudflare codée en dur vers `shared/networking/cloudflare/mail_dns.py` (`MailDnsManager`).
- [x] **Robustesse des Déploiements** : Application globale de `skip_await=False` sur les Helm Charts et utilisation de `depends_on` pour garantir la préservation de l'ordre d'initialisation (attente de création des Secrets/PVCs virtuels avant démarrage pod).
- [x] **Visibilité et Zero-Trust** : Création automatique de Labels K8s globaux (`managed-by: pulumi`, `app`) via Pulumi Transformations, et auto-génération des Egress K8s NetworkPolicies vers CloudNativePG DB.

---

## 🚀 Version 2.0 (Services Locaux & Observabilité)

Une fois le code de base solidifié, nous déploierons les services qui forment le cœur d'usage du "Personal Cloud".

### Observabilité Complète (Kube-Prometheus)
- [ ] Déploiement de `kube-prometheus-stack` sur le cluster pour fournir les CRDs `ServiceMonitor`.
- [ ] Monitoring complet des workloads avec un pont ou un déploiement Grafana Agent / Loki pour la centralisation des logs applicatifs.
- [ ] Alerting critique (Slack/Discord) sur les pannes de Pods ou l'espace disques.

### Productivity & Cloud Personnel
- [ ] **Nextcloud** : Solution unifiée pour les Fichiers, Calendriers et Contacts synchronisés.
- [ ] **Paperless-ngx** : GED pour le traitement OCR et l'archivage de courriers physiques.

### Intelligence Artificielle (Private AI)
- [ ] **Dify** / **AnythingLLM** : Déploiement de RAG et orchestration LLM sur des données privées (n8n integration) gardés sous Authentik.

---

## 🏠 Version 3.0 (Hybrid Cloud & Edge Node)

L'expansion du cluster OCI vers le domicile physique pour gérer des workloads qui ne sont pas supportables dans le Cloud public (Bande passante, Stockage massif, GPUs).

- [ ] **Talos Linux SNC** : Provisionnement d'un "Single Node Cluster" nu physique à la maison.
- [ ] **Fédération Reseau** : Tunneling via *Netbird* ou *Tailscale* pour relier OCI (Control/Gateway) et Local Node (Worker).
- [ ] **Migration des charges lourdes** : Déploiement de *Immich* (Photothèque IA) et refonte de la stach Média (*Jellyfin*, *Radarr*, *Sonarr*) nécessitant un accès de classe réseau local aux NAS.
