# Agent orchestrateur (mode construction homelab)

Ce document décrit **comment intégrer** un orchestrateur d’agent (ticket-driven, GitHub Issues) dans la stack **oci-mgmt**, pour que l’agent tourne sur le VPS et construise le homelab de façon autonome. Référence : `_bmad-output/planning-artifacts/stack-ia-et-services-entrepreneuse.md` (§5, §5.6, §7).

---

## 1. Rôle de l’orchestrateur

- **Poll** les GitHub Issues (label `homelab-agent` ou projet dédié).
- Pour chaque issue : charger le contexte (repo cloné, `implementation-progress.md`, stories), appeler l’API LLM (OpenRouter ou Claude), exécuter les commandes (Terraform, kubectl, git) avec garde-fous.
- En cas de succès : commenter, fermer l’issue, mettre à jour `implementation-progress.md`.
- En cas d’erreur ou de sous-tâche : **créer** de nouvelles issues GitHub, commenter l’issue courante.

L’orchestrateur doit pouvoir accéder au **réseau homelab** (pour parler à Traefik, Postgres, etc. si besoin) et avoir **git**, **terraform**, **kubectl** / **omnictl** disponibles (ou les appeler via un sidecar / une image qui les contient).

---

## 2. Où le faire tourner

- **Option A — Conteneur dans ce Compose**
  Ajouter un service `homelab-agent` dans `docker-compose.yml` :
  - Image : custom (Dockerfile) qui contient Node/Python + git, terraform, kubectl (ou une image minimale + volume monté avec binaires).
  - Variables d’env : `GITHUB_TOKEN`, `OPENROUTER_API_KEY` (ou `ANTHROPIC_API_KEY`), `REPO_OWNER`, `REPO_NAME`, optionnellement `OMNI_KUBECONFIG` ou chemins vers secrets.
  - Volume : clone du repo homelab (ou volume persistant pour le clone) pour lire/epush les fichiers.
  - Réseau : `homelab` pour accéder aux autres services si besoin (ex. API interne).
  - **Pas d’exposition** publique : le conteneur n’a pas besoin d’être derrière Traefik ; il tourne en arrière-plan et poll GitHub.

- **Option B — Process sur l’hôte (systemd)**
  Si tu préfères ne pas mettre git/terraform dans une image : installer Node/Python + deps sur la VM OCI, cloner le repo dans `/opt/homelab-agent`, configurer les env (fichier ou systemd unit), lancer l’orchestrateur en **systemd service**. Même logique que le conteneur, mais plus simple pour accéder à des binaires déjà présents sur l’hôte.

---

## 3. Ce qu’il faut ajouter dans `docker-compose.yml` (option A)

Exemple de squelette (à adapter selon l’image réelle de l’orchestrateur) :

```yaml
# =========================================================================
# Homelab Agent — Orchestrateur ticket-driven (GitHub Issues + LLM)
# =========================================================================
# Optionnel. Décommenter et renseigner .env (GITHUB_TOKEN, OPENROUTER_API_KEY, etc.)
# Référence: _bmad-output/planning-artifacts/stack-ia-et-services-entrepreneuse.md
#
# homelab-agent:
#   image: homelab-agent:latest   # Build: docker build -t homelab-agent -f path/to/Dockerfile .
#   container_name: oci-mgmt-homelab-agent
#   restart: unless-stopped
#   environment:
#     GITHUB_TOKEN: ${GITHUB_TOKEN:?}
#     OPENROUTER_API_KEY: ${OPENROUTER_API_KEY:-}
#     ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:-}
#     REPO_OWNER: ${REPO_OWNER:-}
#     REPO_NAME: ${REPO_NAME:-}
#     LABEL_FILTER: homelab-agent
#     POLL_INTERVAL_SEC: 300
#   volumes:
#     - homelab_agent_repo:/app/repo   # Clone du repo (persistant)
#     # Optionnel: montage de kubeconfig ou secrets
#     # - /path/on/host/kubeconfig:/app/.kube/config:ro
#   networks:
#     - homelab
```

- **Secrets** : ne jamais mettre `GITHUB_TOKEN` ou clés API en clair dans le compose committé ; utiliser un `.env` (gitignored) ou un secret manager.
- **Réseau** : `homelab` suffit si l’agent n’a besoin que de Git (HTTPS) et de l’API LLM (internet). Si plus tard il doit appeler des APIs internes (Omni, Authentik), tout est déjà sur le même réseau.

---

## 4. Variables d’environnement suggérées (.env)

À documenter dans le README ou un `.env.example` (sans valeurs réelles) :

| Variable | Obligatoire | Description |
|----------|-------------|-------------|
| `GITHUB_TOKEN` | Oui (si agent activé) | Token avec `repo` (ou au minimum `issues: read/write`) pour le dépôt homelab. |
| `OPENROUTER_API_KEY` ou `ANTHROPIC_API_KEY` | Une des deux | Clé pour les appels LLM. OpenRouter permet de changer de modèle sans changer de code. |
| `REPO_OWNER` | Oui | Ex. `ton-username`. |
| `REPO_NAME` | Oui | Ex. `homelab`. |
| `LABEL_FILTER` | Optionnel | Label des issues à traiter (ex. `homelab-agent`). Défaut possible dans le code. |
| `POLL_INTERVAL_SEC` | Optionnel | Intervalle de poll (ex. 300). |

---

## 5. Implémentation de l’orchestrateur (hors Docker)

L’orchestrateur lui-même (logique poll → load context → call LLM → execute → comment/create issue) peut être :

- Un **script unique** (Python ou Node) dans le repo homelab (ex. `scripts/homelab-agent/` ou `tools/orchestrator/`), qui sera copié dans l’image Docker ou exécuté sur l’hôte.
- Une **petite app** (FastAPI/Express) qui expose éventuellement un webhook GitHub et un endpoint health pour le monitoring.
- **Claude-Flow** (ou autre framework) en mode headless : voir `stack-ia-et-services-entrepreneuse.md` §5.7 pour les limites (coûts API, pas d’abo fixe qui couvre tout).

Le présent fichier ne contient pas le code de l’orchestrateur ; il décrit uniquement **comment l’intégrer** dans oci-mgmt (Compose, env, volumes, réseau).

---

## 6. Ordre de mise en place

1. **Décider** : conteneur (Option A) vs process hôte (Option B).
2. **Implémenter** l’orchestrateur (poll GitHub, appel LLM, exécution commandes, création issues) dans le repo.
3. **Ajouter** le service dans `docker-compose.yml` (ou la unit systemd) et les variables dans `.env`.
4. **Tester** avec une issue de test (label `homelab-agent`), vérifier qu’aucune action destructive ne part sans garde-fou (ex. label `agent-apply` pour `terraform apply`).
5. **Documenter** dans le README principal de oci-mgmt que le service `homelab-agent` est optionnel et qu’il requiert `GITHUB_TOKEN` + clé API LLM.

---

*Référence : stack-ia-et-services-entrepreneuse.md (mode construction, ticket-driven, §5.4 accès, §7 comment continuer).*
