# Fiche : Stack IA (proxy, DLP, RBAC, agents, données)

Stack self-hosted pour servir l’IA en proxy : **DLP** (prompts et réponses), gestion des providers, **RBAC** (identités type OpenClaw/Kilo), intégration Authentik, **stack RAG** (vector store, embeddings), **observabilité** (logs, métriques, coûts), **limites d’utilisation** (quotas, rate limit), et découvrabilité des données d’entreprise (Nextcloud, bases de données, base documentaire Docusaurus/Git).

---

## 1. Vue d’ensemble

| Composant | Rôle |
|------------|------|
| **LiteLLM Proxy** | Point d’entrée unique : API OpenAI-compatible, routage multi-providers, clés virtuelles, budgets, **RBAC** (teams, model groups), **rate limiting**. Utilisable depuis CI/CD, IDE, Open WebUI, OpenClaw, Kilo. |
| **DLP (entrée + sortie)** | **Pre-call** : `async_pre_call_hook` + llmshield/Presidio → PII/secrets retirés des prompts. **Post-call** : `async_post_call_success_hook` → redaction des réponses avant envoi au client. |
| **Authentik** | SSO / OIDC : authentification des **utilisateurs** (JWT) et, selon choix, identités **agents** (OAuth2 client credentials → JWT). Un seul annuaire pour humains et accès aux apps (dont le proxy). |
| **Open WebUI** | Interface web de chat ; se connecte au proxy en « OpenAI ». |
| **OpenClaw** | Agent open-source (fichiers, shell, intégrations) ; **identité dédiée** dans le proxy (clé + model group restreint, ex. Kimi K2.5). |
| **Kilo** | Plateforme agents de code (IDE, CLI) ; **identité dédiée** (clé + model group). |
| **Stack RAG** | Vector store (ex. Qdrant/pgvector), modèle d’embeddings, pipeline d’indexation (Nextcloud, BDD, Docusaurus), API « search » pour les agents. Voir §4.5. |
| **Observabilité** | Logs des appels (user, modèle, tokens, latence), métriques (Prometheus/Grafana ou équivalent), coûts par team/model, alerting. Voir §6. |
| **Limites d’utilisation** | Quotas par user/team (requêtes/min, tokens/jour), budgets LiteLLM, rate limiting. Voir §7. |
| **Données d’entreprise** | Découvrabilité pour les agents : **Nextcloud** (documents), **bases de données** (hébergement à définir), **base documentaire** (Docusaurus sur Git). Voir §4. |

---

## 2. Architecture cible

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│  Clients                                                                          │
│  • Open WebUI (navigateur)  • OpenClaw  • Kilo (IDE/CLI)  • CI/CD  • IDE (Cursor)  │
└─────────────────────────────────────┬───────────────────────────────────────────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    │  Authentik (SSO / OIDC)             │  ← Identités humains + optionnellement agents
                    │  • Utilisateurs → JWT               │
                    │  • Clients OAuth2 (agents) → JWT    │
                    └─────────────────┬─────────────────┘
                                      │ JWT ou clé virtuelle (délégation)
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│  LiteLLM Proxy (self-hosted)                                                      │
│  • DLP : pre_call (prompts) + post_call (réponses) → redaction PII/secrets        │
│  • RBAC : teams, clés, model groups (accès par identité)                          │
│  • Rate limiting + quotas (req/min, tokens/jour par team)                         │
│  • Routage → Fireworks, Venice, OpenAI, Anthropic, Ollama, …                       │
└─────────────────────────────────────┬───────────────────────────────────────────┘
                                      │  → Observabilité : logs, métriques, coûts (Grafana / SIEM)
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        ▼                             ▼                             ▼
   Fireworks (Kimi K2.5)        Venice.ai (vie privée)         Autres providers
```

---

## 3. Intégration Authentik avec les agents

Objectif : unifier l’identité (humains et, selon besoin, agents) avec **Authentik** et faire en sorte que le proxy LiteLLM respecte ces identités (rôles, accès modèles).

### 3.1 Authentification des **utilisateurs** (humains)

- **Open WebUI** : peut utiliser Authentik en OIDC pour la connexion des utilisateurs (login via Authentik).
- **LiteLLM** : en mode **JWT**, LiteLLM valide le JWT émis par Authentik et applique le **RBAC** selon les rôles portés par le token (accès aux modèles par `role_permissions`).

Configuration LiteLLM (exemple) :

- `enable_jwt_auth: true`
- `JWT_PUBLIC_KEY_URL` = URL JWKS du provider OAuth2/OIDC Authentik (ex. `https://auth.ton-domaine.com/application/o/<provider-slug>/jwks/`). Voir [Authentik OAuth2 Provider](https://docs.goauthentik.io/docs/providers/oauth2) (endpoint JWKS : `/application/o/jwks/`).
- `user_roles_jwt_field` = champ du JWT où sont les rôles (ex. `groups` ou claim custom).
- `role_permissions` = mapping rôle → listes de modèles autorisés.
- `enforce_rbac: true`

Les utilisateurs se connectent à Authentik, obtiennent un JWT (via une app OIDC ou un flow client), et envoient ce JWT au proxy LiteLLM ; l’accès aux modèles est limité par rôle.

Référence : [LiteLLM – OIDC / JWT-based Auth](https://docs.litellm.ai/docs/proxy/token_auth), [Control Model Access with OIDC](https://docs.litellm.ai/docs/proxy/jwt_auth_arch).

### 3.2 Identités **agents** (OpenClaw, Kilo)

Deux approches possibles :

| Approche | Principe | Avantage |
|----------|----------|----------|
| **A. Clés virtuelles LiteLLM** | Tu crées dans LiteLLM des **teams** (ex. « OpenClaw », « Kilo ») et une **clé API** par team, restreinte à un **model group**. Les agents utilisent cette clé (pas de login OIDC). La **création/gestion** des clés se fait par un admin **authentifié via Authentik** (dashboard LiteLLM derrière Authentik ou API admin protégée). | Simple à déployer ; les agents n’ont pas à gérer OAuth2. |
| **B. OAuth2 Client Credentials (Authentik)** | Tu enregistres dans Authentik un **client OAuth2** par agent (OpenClaw, Kilo). L’agent obtient un **JWT** (client_credentials) et l’envoie au proxy. LiteLLM valide le JWT et applique `role_permissions` selon un rôle associé au client (ex. `agent_openclaw` → modèle Kimi uniquement). | Identité des agents **dans** Authentik ; révocation centralisée. |

En pratique : **A** pour démarrer rapidement ; **B** si tu veux que toutes les identités (y compris agents) vivent dans Authentik avec les mêmes politiques et audits.

### 3.3 Récap Authentik

- **Humains** : login Authentik → JWT (ou session) → Open WebUI / apps → proxy LiteLLM en JWT → accès modèles selon rôles.
- **Agents (OpenClaw, Kilo)** : soit clé virtuelle LiteLLM (créée par admin Authentik), soit client OAuth2 Authentik → JWT → proxy → accès limité par rôle/model group.

---

## 4. Découvrabilité des données d’entreprise (pour les agents)

Les agents (OpenClaw, Kilo, ou tout client du proxy) peuvent avoir besoin d’**accéder** ou de **découvrir** les données métier : documents (Nextcloud), bases de données, base documentaire (Docusaurus/Git). Voici des pistes cohérentes avec ta stack.

### 4.1 Documents dans **Nextcloud**

- **APIs utiles** :
  - **FullTextSearch (OCS)** : indexation et récupération de contenu pour RAG. Endpoints type `/ocs/v2.php/apps/fulltextsearch/collection/<name>/index` et `/.../document/<provider_id>/<document_id>`. Voir [Nextcloud FullTextSearch Collection API](https://docs.nextcloud.com/server/latest/developer_manual/client_apis/OCS/ocs-fulltextsearch-collections-api.html).
  - **WebDAV** : listing, lecture de fichiers (filtres, recherche). Voir [WebDAV Search](https://docs.nextcloud.com/server/latest/developer_manual/client_apis/WebDAV/search.html).
- **Pour les agents** :
  - Créer un **compte de service** Nextcloud (ou un utilisateur dédié « agent ») avec des droits limités (dossiers partagés nécessaires).
  - Exposer un **petit service ou script** (dans le homelab) qui : appelle FullTextSearch/WebDAV avec ce compte, agrège les résultats, et les sert à un **pipeline RAG** (embeddings + vector store) ou à une API « search » que les agents appellent.
  - Les agents (OpenClaw, Kilo, ou un assistant dans Open WebUI) utilisent ce pipeline / cette API pour la découvrabilité des documents, sans exposer les credentials Nextcloud aux agents.

Hébergement Nextcloud : inchangé (ex. Nextcloud sur Hetzner comme dans la synthèse Gwen).

### 4.2 Bases de données

- **Hébergement** : à définir (ex. Postgres/MySQL sur Hetzner, ou managed DB du même cloud, ou dans le homelab).
- **Découvrabilité pour les agents** :
  - **Ne pas** donner les connexions DB brutes aux agents.
  - Options :
    - **API métier** : une API (REST ou GraphQL) qui interroge les BDD et expose schémas (read-only) ou requêtes prédéfinies ; les agents appellent cette API.
    - **Couche RAG** : schémas + commentaires ou extraits de données sensibles exportés dans un vector store (avec DLP si besoin) ; les agents posent des questions en langage naturel et reçoivent des réponses générées à partir de ce contexte.
  - Identité : l’API ou le job d’indexation utilise un **compte DB dédié** (lecture seule) ; l’accès à l’API est protégé (Authentik ou clé API) pour que seuls les agents autorisés puissent l’utiliser.

### 4.3 Base documentaire **Docusaurus (Git)**

- **Source de vérité** : dépôt Git (comme dans la synthèse Gwen) ; build Docusaurus = site statique + contenu versionné.
- **Découvrabilité pour les agents** :
  - **Option 1** : **Clone du repo** (ou mirror) sur un serveur accessible aux pipelines : extraction du contenu (Markdown/HTML), indexation dans un **vector store** pour RAG ; les agents interrogent ce RAG (recherche sémantique sur la doc).
  - **Option 2** : **Build Docusaurus** puis crawl du site statique (ou parsing des fichiers générés) pour alimenter le même vector store.
  - **Option 3** : **API Git** (ex. GitHub/GitLab API) pour lister/lire les fichiers du repo ; un service interne agrège et indexe pour RAG.
- Les agents n’ont pas besoin d’accès Git direct : ils utilisent une **API « doc »** ou un **RAG** alimenté par ce contenu, avec droits contrôlés (Authentik ou clé).

### 4.4 Schéma de flux « données → agents »

```
Nextcloud (docs) ──► Compte service / API ──┐
Bases de données ──► API read-only ou RAG ──┼──► Indexation / RAG ──► Vector store + API « search »
Docusaurus (Git) ──► Clone / build / crawl ─┘                                    │
                                                                                  ▼
Agents (OpenClaw, Kilo, Open WebUI) ◄────── Appels API « search » + proxy LLM ◄──┘
```

Tu peux centraliser l’**identité** des agents et des services qui accèdent aux données via **Authentik** (OAuth2 clients ou utilisateurs de service), et garder les credentials réels (Nextcloud, DB, Git) côté backend (indexation + API).

### 4.5 Stack RAG (vector store, embeddings, évaluation)

Pour que le flux « données → agents » soit opérationnel, il faut choisir et déployer les briques suivantes.

| Brique | Rôle | Options recommandées |
|--------|------|------------------------|
| **Vector store** | Stockage des embeddings et recherche par similarité (k-NN). | **Qdrant** (self-hosted, performant), **pgvector** (PostgreSQL, simple si BDD déjà en place), **Weaviate** ou **Chroma** (léger). Hébergement : homelab ou même cloud que les BDD (ex. Hetzner). |
| **Modèle d’embeddings** | Transformation texte → vecteur pour indexation et requêtes. | **Local** : `nomic-embed-text` (Ollama), `sentence-transformers` (GPU/CPU). **API** : OpenAI `text-embedding-3-small`, Voyager (Fireworks), Cohere. Choisir selon coût, langue (FR) et latence. |
| **Pipeline d’indexation** | Alimenter le vector store à partir de Nextcloud, BDD, Docusaurus. | Job planifié (cron) ou événementiel : extraction texte → découpage (chunks) → embeddings → upsert. Outils possibles : **LlamaIndex**, **LangChain** (ingest), ou scripts custom (Python). DLP optionnel sur les chunks avant indexation si données sensibles. |
| **API « search »** | Interface unique pour les agents : question → contexte pertinent. | Service (FastAPI/Flask) qui : prend la requête utilisateur → embedding de la requête → recherche vectorielle → retour des chunks (et métadonnées). Protégé par Authentik ou clé API. Peut inclure re-ranking (optionnel). |
| **Évaluation de la qualité RAG** | Mesurer pertinence et éviter régressions. | Tests sur un jeu de questions/réponses de référence : **recall** (retrieval), **fidélité** (réponse basée sur le contexte), **rélevance**. Outils : **RAGAS**, **LlamaIndex Evaluation**, ou métriques custom (similarité, présence de la réponse dans les chunks). À exécuter en CI ou manuellement après changement d’embeddings ou de chunking. |

**Schéma technique RAG :**

```
Sources (Nextcloud, DB, Docusaurus) → Extraction + chunking → Embeddings → Vector store
                                                                              ↑
Requête agent → API search → Embedding requête → Recherche k-NN → Chunks → Contexte → LLM (proxy)
```

**Backup** : sauvegarder le vector store (snapshots Qdrant, dump pgvector) selon la même politique que les autres données métier.

---

## 5. DLP (Data Loss Prevention) – entrée et sortie

Objectif : éviter que des **données sensibles** (PII, secrets, données internes) partent vers les LLM ou reviennent aux clients dans les réponses.

### 5.1 DLP sur les entrées (prompts)

- **Où** : dans LiteLLM, hook **`async_pre_call_hook`** (ou équivalent) appelé avant l’envoi au provider.
- **Action** : analyser et **redacter** (ou remplacer) dans le corps de la requête (messages, content) :
  - **PII** : emails, téléphones, noms, adresses (regex + NER).
  - **Secrets** : tokens API, mots de passe, clés (patterns + listes).
  - **Données métier sensibles** : selon règles métier (ex. numéros de contrat, codes).
- **Outils** :
  - **llmshield** : lib dédiée LLM, détection PII/secrets, redaction.
  - **Presidio** (Microsoft) : analyseurs + anonymisation, extensible.
  - Implémentation custom : appeler la lib depuis le hook, modifier `kwargs["messages"]` (ou le champ équivalent) puis retourner.

Référence : [LiteLLM – Call Hooks](https://docs.litellm.ai/docs/proxy/call_hooks).

### 5.2 DLP sur les sorties (réponses du LLM)

- **Problème** : le modèle peut régénérer ou reformuler des PII/secrets présents dans le prompt (mal redacté) ou « halluciner » des données sensibles.
- **Où** : dans LiteLLM, hook **`async_post_call_success_hook`** (ou équivalent) appelé après réception de la réponse du provider, **avant** de la renvoyer au client.
- **Action** : sur le contenu de la réponse (texte ou stream) :
  - Appliquer la **même logique** de détection/redaction que pour les prompts (PII, secrets).
  - En mode **streaming** : traiter les chunks au fur et à mesure, ou bufferiser la réponse complète puis redacter avant envoi (selon contraintes latence).
- **Implémentation** : réutiliser la même lib (llmshield/Presidio) que pour le pre-call ; une fonction `redact(text) -> str` utilisée dans les deux hooks.

### 5.3 Récap DLP

| Phase | Hook LiteLLM | Données traitées | Objectif |
|-------|----------------|------------------|----------|
| **Entrée** | `async_pre_call_hook` | Messages (prompt) envoyés au LLM | Ne pas exposer PII/secrets aux providers. |
| **Sortie** | `async_post_call_success_hook` | Réponse renvoyée par le LLM | Ne pas exposer PII/secrets aux clients. |

Optionnel : **logging** des redactions (type d’entité, pas le contenu) pour audit et réglage des règles.

---

## 6. Observabilité (logs, métriques, coûts)

Pour piloter la stack (débogage, coûts, abus, conformité), il faut centraliser les **logs** des appels et les **métriques** d’usage.

### 6.1 Logging des appels

- **Données à capturer** (par requête) :
  - Identité : `user_id` / `team_id`, clé ou JWT (hashé si besoin).
  - Modèle demandé, provider réel.
  - Tokens : input, output, total.
  - Latence (ms), statut (succès/erreur).
  - **Pas** de contenu complet des prompts/réponses (RGPD, volume) ; éventuellement hash ou flag « contient PII » après DLP.
- **Où** : LiteLLM permet d’envoyer les logs vers un **callback** (webhook) ou une **base** (PostgreSQL, etc.). Voir [LiteLLM – Logging](https://docs.litellm.ai/docs/proxy/logging). Envoyer vers un agrégateur (ex. **Loki**, **Elastic**, ou fichier JSON consommé par un pipeline).
- **Rétention** : définir une durée (ex. 90 jours) selon conformité et coût stockage ; politique d’effacement pour RGPD.

### 6.2 Métriques (usage, erreurs, quotas)

- **Métriques utiles** :
  - Requêtes par user/team/model (compteurs).
  - Tokens par user/team/model (input/output).
  - Latence (p50, p95, p99).
  - Taux d’erreur (4xx, 5xx, timeouts).
  - État des quotas (consommé / limite).
- **Collecte** : Prometheus (exposition métriques depuis LiteLLM ou depuis un middleware) ou équivalent ; **Grafana** pour dashboards.
- **Alerting** : seuils sur erreurs, latence, dépassement de quota ou de budget (ex. Prometheus Alertmanager, Grafana alerts).

### 6.3 Coûts (FinOps)

- **Source** : les logs d’appels (tokens par modèle) permettent de calculer le coût par requête si on a un tarif par modèle (ex. $/M tokens).
- **Agrégation** : par team, par user, par modèle, par période (jour/semaine/mois). Stocker dans une base (PostgreSQL, ClickHouse) ou dans un outil dédié (ex. spreadsheets alimentées par un job).
- **Visualisation** : dashboard Grafana (coût par team, évolution dans le temps) ; optionnel : showback / facturation interne.
- **Alertes** : dépassement de budget (équipe ou global) pour réagir avant la fin du mois.

### 6.4 Schéma observabilité

```
LiteLLM Proxy → Logs (webhook/DB) → Agrégateur (Loki/Elastic/Postgres)
                → Métriques (Prometheus) → Grafana (dashboards + alertes)
                → Calcul coûts (tokens × tarifs) → Dashboard FinOps + alertes budget
```

---

## 7. Limites d’utilisation (rate limiting, quotas, budgets)

Pour éviter abus, saturation et dépassement de budget, définir des **limites** par identité (user/team) et les faire appliquer au proxy.

### 7.1 Quotas par user / team

- **Types de limites** :
  - **Requêtes** : nombre de requêtes par minute (ou par heure) par user/team.
  - **Tokens** : nombre de tokens (input + output) par jour ou par mois par user/team.
- **Où** : LiteLLM supporte des **budgets** (en $) et des **limits** par clé/team. Vérifier la doc pour les limites en « requêtes/minute » et « tokens/jour » ([LiteLLM – Budget / Rate Limits](https://docs.litellm.ai/docs/proxy/budget)). Si besoin, mettre un **reverse proxy** (Traefik, Nginx, Kong) devant LiteLLM avec rate limiting par header (api-key) ou par JWT claim (team_id).
- **Valeurs** : à définir selon usage cible (ex. 100 req/min, 1M tokens/jour par team « dev » ; plus élevé pour « prod »).

### 7.2 Budgets (coût max)

- **LiteLLM** : budgets par **team** ou par **clé** (en dollars). Le proxy peut refuser les appels une fois le budget dépassé.
- **Configuration** : définir un budget mensuel (ou par période) par team ; alerter (observabilité) avant d’atteindre la limite pour ajuster ou renouveler.

### 7.3 Rate limiting global (protection proxy)

- **Objectif** : protéger le proxy et les providers contre les pics (bug, script qui boucle).
- **Moyens** : rate limit **global** (requêtes/seconde sur l’instance) dans LiteLLM si disponible, ou dans le reverse proxy (ex. Nginx `limit_req`, Traefik Middleware).
- **Comportement** : retourner HTTP 429 (Too Many Requests) avec un header `Retry-After` si possible.

### 7.4 Récap limites

| Niveau | Mécanisme | Exemple |
|--------|-----------|---------|
| **Par team/user** | Quotas LiteLLM (ou reverse proxy) | 100 req/min, 1M tokens/jour |
| **Coût** | Budget LiteLLM par team/clé | 50 €/mois par team |
| **Global** | Rate limit reverse proxy / LiteLLM | 500 req/s sur le proxy |

---

## 8. Composants de la stack (récap)

| Composant | Rôle | Référence |
|-----------|------|------------|
| **LiteLLM Proxy** | Proxy OpenAI-compatible, DLP, RBAC, rate limiting, multi-providers | [docs.litellm.ai](https://docs.litellm.ai) |
| **DLP** | llmshield ou Presidio : `async_pre_call_hook` (prompts) + `async_post_call_success_hook` (réponses) | [LiteLLM call hooks](https://docs.litellm.ai/docs/proxy/call_hooks) |
| **Authentik** | SSO, OIDC, JWT pour utilisateurs et (optionnel) clients agents | [Authentik OAuth2](https://docs.goauthentik.io/docs/providers/oauth2) |
| **Open WebUI** | Interface web chat | [Open WebUI – OpenAI-compatible](https://docs.openwebui.com/getting-started/quick-start/starting-with-openai-compatible) |
| **OpenClaw** | Agent (fichiers, shell) ; identité + model group dédiés | [Configuration](https://clawdbot.online/configuration/) |
| **Kilo** | Agents de code ; identité + model group dédiés | [kilo.ai](https://kilo.ai) |
| **Kimi K2.5** | Via **Fireworks** (LiteLLM provider `fireworks_ai`) ou **Venice** (api_base custom) | [Fireworks](https://fireworks.ai/), [Venice + LiteLLM](https://venice.ai/blog/how-to-use-venice-api-with-litellm) |
| **Stack RAG** | Vector store (Qdrant/pgvector), embeddings (Ollama/API), pipeline (LlamaIndex/LangChain), API search | §4.5 ; [Qdrant](https://qdrant.tech/), [LlamaIndex](https://www.llamaindex.ai/) |
| **Observabilité** | Logs (Loki/Elastic/Postgres), métriques (Prometheus), dashboards et coûts (Grafana) | §6 ; [LiteLLM Logging](https://docs.litellm.ai/docs/proxy/logging) |
| **Limites** | Quotas (req/min, tokens/jour), budgets LiteLLM, rate limit (proxy ou reverse proxy) | §7 ; [LiteLLM Budget](https://docs.litellm.ai/docs/proxy/budget) |
| **Nextcloud** | Documents ; découvrabilité via FullTextSearch + WebDAV → RAG/API | [FullTextSearch API](https://docs.nextcloud.com/server/latest/developer_manual/client_apis/OCS/ocs-fulltextsearch-collections-api.html) |
| **Bases de données** | Hébergement à définir ; découvrabilité via API ou RAG (pas d’accès direct aux agents) | — |
| **Docusaurus (Git)** | Base documentaire ; découvrabilité via clone/crawl → RAG | — |

---

## 9. Ordre de mise en place suggéré

1. **LiteLLM Proxy** : config de base, 1–2 providers (ex. Fireworks pour Kimi K2.5), une clé de test.
2. **DLP entrée** : activation de `async_pre_call_hook` + llmshield (ou Presidio).
3. **DLP sortie** : activation de `async_post_call_success_hook` avec la même logique de redaction (réponses).
4. **RBAC** : création des teams (ex. OpenClaw, Kilo) et model groups ; clés dédiées.
5. **Limites d'utilisation** : quotas par team (req/min, tokens/jour), budgets LiteLLM ; rate limit global si besoin (reverse proxy).
6. **Observabilité** : logging des appels (webhook/DB), Prometheus + Grafana (métriques, dashboards), calcul des coûts et alertes budget.
7. **Authentik** : provider OIDC, JWKS pour LiteLLM ; rôles et `role_permissions` ; connexion Open WebUI à Authentik.
8. **OpenClaw / Kilo** : config avec URL proxy + clé (ou client OAuth2 Authentik si choisi).
9. **Stack RAG** : choix vector store + embeddings ; pipeline d'indexation (Nextcloud, puis BDD, Docusaurus) ; API « search » ; évaluation qualité (RAGAS ou équivalent).
10. **Découvrabilité** : branchement des agents sur l'API search et les sources autorisées ; politique d'accès (Authentik/clé).

*Fiche alignée avec la stratégie homelab (Authentik, Nextcloud Hetzner, base doc Docusaurus/Git) et la fiche « Synthèse outils entrepreneuse ».*
