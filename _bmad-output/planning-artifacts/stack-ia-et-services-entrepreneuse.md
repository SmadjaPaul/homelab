---
date: 2026-02-10
project: homelab
version: 1.0
status: current
lastUpdated: 2026-02-10
inputDocuments:
  - docs/fiche-stack-ia.md
  - docs/synthese-outils-entrepreneuse.md
purpose: Intégration de la stack IA (autonomie des agents) et des services entreprise dans le planning homelab
---

# Stack IA & Services entreprise — Intégration planning

Ce document intègre dans le planning BMad (_bmad-output) la **stack IA** (fiche-stack-ia.md) et les **services principaux** de la synthèse outils entrepreneuse (Fleet, Odoo, Migadu, DocuSeal, Docusaurus). Objectif : permettre une **implémentation rapide de la stack IA** pour que des agents (OpenClaw, Kilo, Cursor, etc.) puissent **finaliser la création du homelab en autonomie**, tout en alignant le catalogue de services sur les besoins entreprise.

---

## 1. Références sources

| Document | Contenu principal |
|----------|-------------------|
| **docs/fiche-stack-ia.md** | LiteLLM Proxy, DLP (prompts + réponses), RBAC/Authentik, stack RAG (vector store, embeddings, API search), observabilité (logs, métriques, coûts), limites d’utilisation (quotas, rate limit). Données : Nextcloud, BDD, Docusaurus. Ordre de mise en place §9. |
| **docs/synthese-outils-entrepreneuse.md** | Stratégie « rien en local » (Fleet + Ansible), mail (Migadu Terraform), données (Nextcloud Hetzner), services support : Authentik, **Odoo**, **DocuSeal**, Mattermost/Element, **base documentaire Docusaurus**. **Fleet** : MDM, inventaire, politiques, lock/wipe. **Migadu** : provider Terraform metio/migadu. |

---

## 2. Objectif : stack IA pour finaliser le homelab en autonomie

La stack IA sert à :

1. **Exposer un point d’entrée unique** (LiteLLM Proxy) pour tous les clients (IDE, Open WebUI, agents OpenClaw/Kilo, CI/CD).
2. **Sécuriser** les échanges (DLP entrée/sortie, RBAC, Authentik).
3. **Donner du contexte aux agents** via la stack RAG (doc homelab, Docusaurus, Nextcloud, schémas BDD) pour qu’ils puissent proposer ou générer des changements cohérents (manifests, Terraform, runbooks).
4. **Piloter** l’usage (observabilité, quotas, coûts).

**Ordre recommandé pour une mise en place rapide** (aligné fiche-stack-ia §9) :

1. LiteLLM Proxy (config de base, 1–2 providers).
2. DLP entrée + sortie (pre_call + post_call).
3. RBAC (teams, model groups, clés).
4. Limites (quotas, budgets).
5. Observabilité (logs, métriques, coûts).
6. Authentik (déjà dans le homelab ; brancher JWT pour LiteLLM).
7. Stack RAG : vector store + embeddings + pipeline (Docusaurus, Nextcloud, BDD) + API « search ».
8. Agents (OpenClaw, Kilo) avec identité dédiée.
9. Branchement des agents sur l’API search et les sources autorisées.

Les **epics/stories** correspondantes sont dans [epics-and-stories-homelab.md](epics-and-stories-homelab.md) (Phase 4b — Stack IA).

---

## 3. Services entreprise intégrés au catalogue

Services principaux retenus (synthèse outils entrepreneuse) à ajouter au PRD et aux epics :

| Service | Rôle | Emplacement cible | FR / Epic |
|---------|------|-------------------|-----------|
| **Fleet (FleetDM)** | MDM : inventaire postes, politiques, lock/wipe, visibilité USB (osquery). Stratégie « aucune donnée en local ». | Homelab (PROD ou CLOUD) ou VM dédiée | FR-033 / Epic 4.7 |
| **Odoo** | CRM, ventes, facturation, stock, congés. | CLOUD cluster (Authentik SSO) | FR-034 / Epic 4.7 |
| **Migadu** | Mail pro (IMAP/SMTP), Terraform natif (metio/migadu). Pas d’hébergement dans le homelab ; **IaC** pour mailboxes, alias, réponses auto. | Externe (Terraform) | FR-035 / Epic 4.7 |
| **DocuSeal** | Signature électronique (contrats, NDA, avenants). | CLOUD cluster (Authentik SSO) | FR-036 / Epic 4.7 |
| **Docusaurus** | Base documentaire (procédures, onboarding, savoir métier). Git = source de vérité ; consultable/éditable (Obsidian en local). Source pour le RAG de la stack IA. | Git + build (CLOUD ou CI) ; RAG alimenté par le repo | FR-037 / Epic 4.7 |

Ces services sont ajoutés au **PRD** (nouveaux FR), au **catalogue de services** et aux **epics-and-stories** (Phase 4b — Services entreprise).

---

## 4. Mapping PRD / Epics

### Nouveaux FR (PRD)

| FR | Titre | Phase |
|----|-------|-------|
| FR-032 | Stack IA (LiteLLM, DLP, RAG, observabilité, limites) | Phase 4b |
| FR-033 | Fleet (FleetDM) — MDM, inventaire, politiques | Phase 4b |
| FR-034 | Odoo — CRM, facturation (Authentik SSO) | Phase 4b |
| FR-035 | Migadu — Mail en IaC (Terraform metio/migadu) | Phase 4b |
| FR-036 | DocuSeal — Signature électronique (Authentik SSO) | Phase 4b |
| FR-037 | Docusaurus — Base documentaire (Git + RAG) | Phase 4b |

### Nouveaux Epics (Phase 4b)

| Epic | Titre | FR |
|------|-------|-----|
| 4.6 | Stack IA (LiteLLM, DLP, RAG, observabilité, limites) | FR-032 |
| 4.7 | Services entreprise (Fleet, Odoo, Migadu, DocuSeal, Docusaurus) | FR-033 à FR-037 |

---

## 5. Mode construction (MVP agent) — sans DLP ni proxy

**En phase de construction du homelab**, tu peux te passer de la stack complète (DLP, LiteLLM Proxy, RBAC, quotas, observabilité). L’objectif minimal : **un agent semi-autonome sur ton VPS**, avec les **accès nécessaires**, qui peut construire l’ensemble du homelab en s’appuyant sur le repo et la doc.

### 5.1 Ce dont tu as besoin (minimum)

| Brique | Rôle en mode construction |
|--------|---------------------------|
| **Un agent** | OpenClaw, ou un agent custom (Python/Node) qui peut : lire le repo, lancer Terraform / kubectl / scripts, appeler des APIs (Omni, GitHub, Cloudflare). Peut tourner sur le VPS (oci-mgmt ou une VM dédiée). |
| **Accès LLM** | Une **clé API directe** (OpenAI, Fireworks, Venice, Ollama, etc.) dans l’environnement de l’agent. Pas besoin de proxy : l’agent appelle le provider en direct. |
| **Contexte** | Le **repo Git** (homelab) = source de vérité : epics, stories, Terraform, manifests, docs. L’agent lit `_bmad-output/`, `docs/`, `terraform/`, `kubernetes/` pour savoir quoi faire ensuite. Optionnel : un petit RAG (vector store + embeddings du repo) pour « quelle est la prochaine story ? ». |
| **Accès techniques** | **Git** (clone/push avec deploy key ou token), **Terraform** (OCI, Proxmox, Cloudflare — credentials en env ou secret manager), **kubeconfig** (Omni/`omnictl` ou kubeconfig des clusters), **secrets** (Bitwarden CLI ou variables d’env) pour les API keys. |

### 5.2 Ce que tu peux ignorer en phase construction

- **LiteLLM Proxy** : pas nécessaire ; l’agent utilise une clé API directe.
- **DLP (entrée/sortie)** : pas nécessaire en environnement de confiance, un seul opérateur.
- **RBAC / quotas / observabilité** : à ajouter plus tard, une fois le homelab en place et plusieurs utilisateurs/clients.

### 5.3 Où faire tourner l’agent

- **Sur le VPS (oci-mgmt)** : idéal si le VPS a déjà accès à Omni, Terraform, Git. L’agent peut lancer des jobs (Terraform apply, `talosctl`, `kubectl`, scripts Ansible).
- **En local (Cursor + agent)** : tu gardes le contrôle ; l’agent te propose des patches ou des commandes, tu valides. Pour de l’autonomie plus forte, le déplacer sur le VPS.

### 5.4 Accès à donner à l’agent (checklist)

Pour qu’il puisse **construire** le homelab sans toi :

| Accès | Comment | Usage |
|-------|--------|--------|
| **Repo homelab** | Deploy key (read + write si l’agent pousse des commits) ou token GitHub | Lire epics/stories, Terraform, manifests ; pousser des changements. |
| **Terraform** | Variables d’env ou secret store (OCI, Proxmox, Cloudflare) | Apply/plan OCI, Proxmox, Cloudflare. |
| **Omni / Kubernetes** | `omnictl` ou kubeconfig (fichier ou env) | Créer clusters, récupérer kubeconfig, déployer via ArgoCD ou kubectl. |
| **Clé API LLM** | Variable d’env (ex. `OPENAI_API_KEY`, `FIREWORKS_API_KEY`) | Appels au modèle pour décisions et génération de code. |
| **Secrets (optionnel)** | Bitwarden CLI ou ESO / Vault | Récupérer les secrets pour Terraform et les apps. |

Une fois ces accès en place, l’agent peut enchaîner les stories (ex. lire [implementation-progress.md](implementation-progress.md), choisir la prochaine tâche, exécuter Terraform / manifests, mettre à jour le suivi).

### 5.5 Choix LLM / plateforme : meilleur rapport qualité–prix pour un agent autonome sur VPS

Comparatif pour **un agent qui tourne seul sur le VPS** et appelle une API LLM (pas d’humain devant un IDE en continu).

| Option | Type | Autonome sur VPS ? | Qualité | Prix (ordre de grandeur) | Commentaire |
|--------|------|--------------------|---------|---------------------------|-------------|
| **OpenRouter** | Agrégateur d’APIs (1 clé, 300+ modèles) | ✅ Oui (API HTTP) | Selon modèle choisi (Claude, GPT, Llama…) | Pay-as-you-go : tarif du provider + ~5,5 % ; tier gratuit : 25+ modèles, 50 req/jour. Ex. Claude 3.5 Haiku ~0,25 $ / 1M input, 1,25 $ / 1M output. | **Meilleur rapport souplesse / prix** : une seule clé, tu changes de modèle sans changer de code. Gratuit pour tester, puis payant au réel usage. |
| **Claude API (Anthropic)** | API directe | ✅ Oui (API HTTP) | Très bon (Sonnet, Haiku) | Haiku : ~0,80 $ / 1M input, 4 $ / 1M output. Sonnet : ~3 $ / 15 $ (input/output). Pas de tier gratuit officiel. | **Meilleur rapport qualité/prix si tu restes sur Claude** : pas de marge OpenRouter. Idéal si tu veux uniquement Claude (Haiku = pas cher, Sonnet = plus capable pour le code). |
| **Kilo Code** | Plateforme agent (IDE/CLI + crédits) | ⚠️ Partiel | Bon (utilise des modèles derrière) | Abo Kilo (ex. 19 $/mois Starter) + crédits 1:1 provider ; ou BYOK (ta clé OpenRouter/Claude). Open source : Ollama/LM Studio en local. | **Agent « clé en main »** pour le code, mais orienté usage interactif (toi + IDE/CLI). Pour un *daemon* sur le VPS qui tourne sans IDE, un script qui appelle OpenRouter/Claude est plus adapté. Kilo utile si tu veux une UI agent sans tout coder. |
| **Cursor** | IDE (éditeur) | ❌ Non | Très bon | Abo Cursor (ex. 20 $/mo Pro) ou **BYOK** : tu paies uniquement le provider (OpenAI, Anthropic, etc.). | **Pas pour l’autonomie sur le VPS** : Cursor = sur ta machine, toi au clavier. Pour « agent autonome sur VPS », il ne remplace pas un process qui appelle une API. En revanche, **en local** : Cursor + BYOK (Claude ou OpenRouter) = bon rapport qualité/prix pour *toi* qui codes. |

**Recommandation pour un agent autonome sur le VPS** :

1. **OpenRouter** : une clé `OPENROUTER_API_KEY`, l’agent appelle `https://openrouter.ai/api/v1/chat/completions` avec le `model` de ton choix (ex. `anthropic/claude-3.5-haiku`, `anthropic/claude-3.5-sonnet`). Tu peux commencer en gratuit (tier free) puis passer en pay-as-you-go. Coût réel proche du provider + 5,5 %.
2. **Claude API direct** : si tu veux **uniquement** Claude et le meilleur prix sans intermédiaire, utilise `ANTHROPIC_API_KEY` et l’API Anthropic. Claude 3.5 Haiku suffit pour beaucoup de tâches (Terraform, scripts) ; passer à Sonnet pour les stories plus complexes.
3. **Kilo** : pertinent si tu préfères un produit « agent de code » avec interface (Kilo IDE/CLI) et que tu acceptes de l’utiliser en mode interactif ou en le branchant sur ton VPS (si Kilo propose un mode headless / API). Vérifier la doc Kilo pour un usage type « agent en arrière-plan sur serveur ».
4. **Cursor** : à réserver pour **ton** usage local (toi qui pilotes le homelab avec l’IDE). Pour le VPS, ce n’est pas Cursor qui tourne, c’est ton agent (script ou OpenClaw) qui appelle OpenRouter ou Claude.

**En résumé** : pour **qualité/prix + autonomie sur VPS**, le plus simple est **OpenRouter** (une clé, tous les modèles, gratuit pour démarrer) ou **Claude API direct** (Haiku pour le coût, Sonnet pour la qualité). Cursor et Kilo sont complémentaires (toi en local, ou agent avec UI) mais ne remplacent pas une API appelée par un process sur le VPS.

### 5.6 Autonomous ticket-driven mode (8h+ unattended, GitHub Issues)

**Can Claude “work for 8 hours straight” without you prompting?**  
Claude (the API) is **stateless**: you send a request, you get a response. It doesn’t “run” for 8 hours. What runs for 8 hours is your **orchestrator** (a process on the VPS). That process can run indefinitely; each time it needs a decision or code, it **calls** Claude (or OpenRouter). So **yes** – the **system** can run autonomously for 8+ hours, with Claude used on every task, without you being there.

**Architecture: ticket-driven, with issue creation**

To have the system **driven by tickets** and **create issues** when it sees errors or new work:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  GitHub (or other ticketing)                                              │
│  • Issues = queue of work (e.g. “Implement story 3.2.1”, “Fix Terraform”) │
│  • Agent creates new issues when: error found, follow-up task, or “to do” │
└─────────────────────────────────────────────────────────────────────────┘
                    │                                    ▲
                    │ poll / webhook                     │ create issue
                    ▼                                    │
┌─────────────────────────────────────────────────────────────────────────┐
│  Orchestrator (runs on VPS, 8h+ or 24/7)                                 │
│  1. Fetch open issues (e.g. label “homelab-agent” or project column)     │
│  2. For each issue: load context (repo, implementation-progress, story)   │
│  3. Call Claude API: “Given this issue and context, what should I do?”    │
│  4. Execute: run Terraform / kubectl / git / scripts (with safeguards)     │
│  5. If success: comment on issue, close, update implementation-progress│
│  6. If error or new work: create new GitHub issue(s), comment on current  │
│  7. Loop or sleep; repeat                                                │
└─────────────────────────────────────────────────────────────────────────┘
```

**What you need**

| Component | Role |
|-----------|------|
| **Long-running worker** | Process (Python/Node/Go) or systemd service that runs on the VPS. It loops: poll issues → process one → call Claude → execute → create/close issues. Can run 8h or 24/7. |
| **Claude (or OpenRouter)** | Called **per task**, not “for 8 hours”. Each issue = one or several API calls (plan, then code, then maybe “summarize error and suggest issue title”). |
| **GitHub API** | List issues (filter by label/project), get issue body, create issue, add comment, close issue. Use a token with `repo` (or `issues: write`). |
| **Triggers** | **Polling** (e.g. every 5 min: “any open issue with label `homelab-agent`?”) or **webhook** (GitHub → your VPS endpoint when an issue is opened/edited). |
| **Create-issue rules** | In the orchestrator: when a step fails (e.g. Terraform error, test failure), call Claude to summarize and suggest a title/body, then `POST /repos/:owner/:repo/issues`. Same for “I need to implement X first” → create an issue for X. |

**Safeguards for unattended runs**

- **Destructive actions** : require a label (e.g. `agent-apply`) or a keyword in the issue body to run `terraform apply` or similar; otherwise only plan/dry-run.
- **Rate limits** : throttle GitHub API and Claude API (e.g. max N issues per hour, max M Claude calls per issue) to avoid runaway cost or API bans.
- **Idempotency** : design so re-processing the same issue doesn’t double-apply (e.g. check “already done” in a comment or in `implementation-progress.md` before applying).

With this, **Claude is capable** of supporting 8 hours (or more) of autonomous work: the orchestrator runs continuously and uses Claude on each ticket; when something goes wrong or new work is needed, the orchestrator creates GitHub issues so the next loop (or you) can handle them.

### 5.7 Claude-Flow, coûts API et option 20 €/mois

**Qu’est-ce que Claude-Flow ?**  
[Claude-Flow](https://github.com/ruvnet/claude-flow) est un **framework d’orchestration** pour Claude Code (IDE/CLI Anthropic) : multi-agents (60+), swarms, MCP, intégration GitHub, hooks, mémoire vectorielle (HNSW). Il est conçu pour être utilisé **avec** Claude Code (ou Codex) en mode interactif ou headless ; les appels LLM passent par **ta clé API** (Anthropic, OpenAI, ou Ollama en local).

**Peut-il gérer l’implémentation globale du homelab avec un abonnement à 20 €/mois ?**  
- **Non, pas “juste” 20 €/mois sans coût supplémentaire.** Claude-Flow ne vend pas d’abonnement “tout compris” : c’est du **BYOK** (Bring Your Own Key). Les coûts réels viennent des **APIs des providers** (Anthropic, OpenAI, etc.) en fonction du volume de tokens. Un abo type Cursor Pro ou crédits à 20 €/mois couvre soit des crédits inclus (souvent limités), soit l’accès à l’outil ; dès que l’agent enchaîne beaucoup de tâches (Terraform, code, revues), la facturation API peut dépasser largement 20 €/mois et n’est **pas plafonnée** par défaut.
- **Pour être sûr de ne pas avoir de coûts API imprévisibles** :
  1. **Plafond strict** : définir un **budget** chez ton provider (OpenRouter ou Anthropic proposent des plafonds / alertes). Arrêter l’orchestrateur ou basculer en “dry-run” quand le budget est atteint.
  2. **Modèles locaux (Ollama)** : Claude-Flow supporte Ollama. Si l’orchestrateur n’utilise qu’Ollama sur le VPS, **coût API = 0** ; en revanche la qualité et la vitesse peuvent être inférieures pour des tâches complexes (Terraform, gros refactors).
  3. **Hybride** : réserver les modèles cloud (Claude/OpenRouter) aux tâches critiques ou à fort impact, et utiliser Ollama pour le reste ; ou limiter le nombre d’appels par issue (ex. 1 plan + 1 exécution max).

**En résumé** : Claude-Flow est pertinent pour **structurer** des agents (MCP, swarms, GitHub) autour de Claude Code, mais il **ne remplace pas** la gestion des coûts API. Pour une implémentation globale du homelab avec **coûts prévisibles** : plafond de budget côté API **ou** usage d’Ollama (coût 0, qualité variable). Voir aussi [docker/oci-mgmt/AGENT-ORCHESTRATOR.md](../../docker/oci-mgmt/AGENT-ORCHESTRATOR.md) pour l’intégration de l’orchestrateur dans la stack oci-mgmt.

---

## 6. Ordre de mise en œuvre recommandé

### Option A — Mode construction (recommandé pour démarrer)

1. **Mettre en place l’agent sur le VPS** : installer l’agent (OpenClaw ou script/cron + LLM) sur oci-mgmt (ou VM dédiée).
2. **Donner les accès** : Git (deploy key/token), Terraform (OCI, Proxmox, Cloudflare), Omni/kubeconfig, clé API LLM (env).
3. **Alimenter le contexte** : le repo est déjà la source de vérité ; optionnel : indexer le repo (ou `_bmad-output/` + `docs/`) dans un petit RAG pour « prochaine story / quoi faire ».
4. **Lancer la construction** : l’agent lit [implementation-progress.md](implementation-progress.md) et [epics-and-stories-homelab.md](epics-and-stories-homelab.md), choisit la prochaine tâche, exécute (Terraform, kubectl, scripts), met à jour le suivi. Tu valides les étapes critiques (ex. first apply Terraform) si besoin.
5. **Plus tard** : une fois le homelab en place, ajouter proxy, DLP, RBAC, observabilité (Option B) si tu exposes l’IA à d’autres usages ou utilisateurs.

### Option B — Stack IA complète (après construction)

1. **Phase 4b — Stack IA (Epic 4.6)** : déployer LiteLLM, DLP, RBAC, limites, observabilité, puis RAG et API search. Brancher Authentik (JWT) et, si besoin, Open WebUI / agents.
2. **Phase 4b — Services entreprise (Epic 4.7)** : déployer Fleet, Odoo, DocuSeal, Docusaurus ; configurer Migadu en Terraform.
3. **Restant du homelab** : les agents s’appuient sur la stack IA (contexte RAG) pour les stories restantes ou la maintenance.

---

## 7. Comment continuer (étapes concrètes)

**Prochaines étapes immédiates (mode construction)** :

1. **Choisir l’agent**  
   - **OpenClaw** : agent polyvalent (fichiers, shell, intégrations). À déployer sur le VPS, configurer avec une clé API LLM directe (pas de proxy).  
   - **Alternative** : petit script ou worker (Python/Node) qui lit les stories, appelle un LLM (API directe), exécute des commandes (Terraform, kubectl) et met à jour le repo. Tu peux le faire évoluer vers OpenClaw ensuite.

2. **Préparer le VPS (oci-mgmt)**  
   - Docker (déjà en place si Omni/Authentik y sont).  
   - Installer : `git`, `terraform`, `kubectl` / `omnictl`, éventuellement Ansible.  
   - Créer un utilisateur ou un répertoire dédié pour l’agent (ex. `/opt/homelab-agent` ou un container).

3. **Configurer les accès (voir §5.4)**  
   - **Git** : deploy key (read/write) pour le repo homelab, cloner le repo sur le VPS.  
   - **Terraform** : exporter les variables ou utiliser un secret store (Bitwarden CLI, ou fichier chiffré SOPS).  
   - **Omni** : installer `omnictl`, configurer le kubeconfig (ou le récupérer depuis Omni).  
   - **LLM** : `OPENAI_API_KEY` ou `FIREWORKS_API_KEY` (ou autre) en variable d’environnement pour l’agent.

4. **Donner le contexte à l’agent**  
   - Pointer l’agent vers le repo cloné : `_bmad-output/planning-artifacts/implementation-progress.md` (prochaine tâche), `epics-and-stories-homelab.md` (détail des stories), `architecture-proxmox-omni.md`, et les dossiers `terraform/`, `kubernetes/`.  
   - Optionnel : indexer ces chemins dans un vector store (Ollama + embeddings + Qdrant/Chroma) pour que l’agent pose des questions du type « quelle est la prochaine story à faire pour Phase 3 ? ».

5. **Lancer une première tâche**  
   - Choisir une story « safe » (ex. 3.2.1 Provision OCI Compute si pas encore fait, ou une story de doc).  
   - L’agent : lit la story, propose les commandes ou patches, les exécute (ou te les affiche pour validation).  
   - Après succès : mettre à jour `implementation-progress.md` (cocher la story) et enchaîner.

6. **Itérer**  
   - Étendre les accès si besoin (ex. Proxmox pour Terraform local).  
   - Ajouter des garde-fous (ex. ne pas apply Terraform sans confirmation, ou seulement sur une branche dédiée).  
   - Quand le homelab est suffisamment avancé, décider si tu actives la stack complète (proxy, DLP, RAG central) pour d’autres usages.

---

## 8. Références croisées

- **PRD** : [prd-homelab-2026-01-29.md](prd-homelab-2026-01-29.md) — nouveaux FR-032 à FR-037 ; catalogue mis à jour.
- **Epics & Stories** : [epics-and-stories-homelab.md](epics-and-stories-homelab.md) — Phase 4b, Epics 4.6 et 4.7.
- **Architecture** : [architecture-proxmox-omni.md](architecture-proxmox-omni.md) — à jour avec Stack IA et services entreprise si nécessaire.
- **Implémentation** : [implementation-progress.md](implementation-progress.md) — suivi Phase 4b.

---

*Document créé pour intégrer docs/fiche-stack-ia.md et docs/synthese-outils-entrepreneuse.md dans _bmad-output et permettre une implémentation rapide de la stack IA en vue d’une finalisation autonome du homelab.*
