# 🗺️ Roadmap Homelab

Ce document définit la vision à court, moyen et long terme de la plateforme Homelab, inspirée des revues d'architecture et du catalogue de services actuel.

## 🌟 Version 1.0 (✅ Terminée)

La V1.0 a établi les fondations sécurisées, l'infrastructure-as-code déclarative et l'identité unifiée.

### Core Infrastructure & Sécurité
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

## 🛠️ Version 1.1 (Refactoring & Dette Technique)

Avant d'ajouter de lourds composants, cette étape vise à traiter la dette technique soulevée lors de la *Revue d'Architecture*.

### Design Patterns K8s
- [ ] **Strategy Pattern pour Helm** : Refactoriser `generic.py` (`get_final_values()`) en utilisant des adaptateurs dédiés (ex: `StandardAdapter`, `AuthentikAdapter`) pour supprimer le code "spaghetti".
- [ ] **Découplage des Registries** : Scinder `registry.py` (qui viole le principe de responsabilité unique) en plusieurs entités plus digestes : `AuthentikRegistry` et `KubernetesRegistry`.
- [ ] **Modularisation du DNS** : Extraire la configuration DNS Email Cloudflare actuellement codée en dur dans le fichier `__main__.py` de la stack "apps" vers une classe autonome `MailDnsManager`.

### Robustesse des Déploiements
- [ ] **Synchronisation des dépendances `auto_secrets`** : Assurer que la Helm Release Pulumi attend la création effective des K8s Secrets (`release_depends_on`) pour éviter les crashs de démarrage Pod (`CreateContainerConfigError`).
- [ ] **Network Policies** : Gérer dynamiquement les Egress vers les bases de données pour les `initContainers` si app.database.local est True.
- [ ] **Validation Rigoureuse** : Passer `skip_await=False` par défaut sur les Helm Charts métier pour s'assurer que Pulumi ne marque le stack "Terminé" que si les pods sont "Ready" (pas de CrashLoopBackOff ignorés).

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
