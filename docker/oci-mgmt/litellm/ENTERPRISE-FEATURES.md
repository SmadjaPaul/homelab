# LiteLLM — Pistes de fonctionnalités (open-source + Enterprise)

Référence : [LiteLLM Enterprise Features](https://docs.litellm.ai/docs/proxy/enterprise). Certaines options sont disponibles en open-source, d’autres nécessitent une licence Enterprise.

---

## Utiles pour ton homelab (sans licence)

- **Bloquer les crawlers**
  `general_settings.block_robots: true` dans `config.yaml` → `/robots.txt` renvoie `Disallow: /`. Utile pour ne pas faire indexer l’UI/admin.

- **Paramètres obligatoires**
  `general_settings.enforced_params: ["user", "metadata.generation_name"]` pour forcer la présence de `user` et de métadonnées sur chaque requête (traçabilité, par clé ou par app).

- **Taille max requête / réponse**
  `general_settings.max_request_size_mb` et `max_response_size_mb` pour limiter la taille des requêtes et éviter les abus (ex. 32 MB en prod).

- **Guardrails — masquage de secrets**
  En open-source : `litellm_settings.callbacks: ["hide_secrets"]` pour détecter et remplacer par `[REDACTED]` les clés API / secrets dans le contenu envoyé au LLM. Réduit le risque de fuite dans les logs ou vers le modèle.

- **Budgets et rate limits**
  Déjà disponibles en open-source (voir [Budgets, Rate Limits](https://docs.litellm.ai/docs/proxy/users)) : budgets par clé, par équipe, `rpm_limit` / `tpm_limit`. À configurer dans `config.yaml` ou via l’API pour garder un coût prévisible (ex. avec Synthetic).

- **Spend tracking**
  Endpoint `/spend/tags` et logs de dépenses par tag. Utile pour suivre l’usage par app (Cline, aichat, etc.) sans licence.

---

## Intéressantes avec une licence Enterprise

- **SSO pour l’Admin UI**
  Connexion à l’interface admin via ton IdP (déjà couvert côté accès par Authentik en Forward Auth ; la licence ajoute l’intégration directe dans LiteLLM si besoin).

- **Audit logs avec rétention**
  Historique des actions admin et des accès avec politique de rétention (compliance, debug).

- **Secret Managers**
  Intégration AWS Secrets Manager, Google Secret Manager, Azure Key Vault, HashiCorp Vault pour injecter les clés API (Synthetic, etc.) sans les mettre en clair dans la config.

- **Contrôle des routes publiques / privées**
  Choisir quelles routes sont exposées publiquement et lesquelles restent réservées à l’admin (Swagger, endpoints internes).

- **Export des logs vers GCS / Azure Blob**
  Export des requêtes LLM vers un bucket pour analyse, coûts ou conformité.

- **Guardrails / modération par clé ou par équipe**
  Activer/désactiver `hide_secrets`, modération de contenu (LLM Guard, Google Text Moderation, etc.) par clé ou par équipe.

- **Budgets en USD par tag**
  Plafonds de dépense en dollars par tag (en plus des limites par requêtes/tokens), avec alertes.

---

## Recommandation rapide

Pour ton usage actuel (Synthetic, Cline, aichat, Authentik) :

1. Activer **`hide_secrets`** et **`block_robots`** dans `config.yaml`.
2. Définir **budgets / rate limits** par clé ou par “team” pour rester dans les 125 req / 5h (Standard Synthetic).
3. Optionnel : **`enforced_params`** (ex. `user`) pour tracer l’usage par outil ou utilisateur.
4. Si tu adoptes un secret manager (Vault, OCI Vault) : envisager la licence pour **Secret Managers** ; sinon garder les clés dans Terraform / env pour l’instant.

Les fonctionnalités listées ci-dessus peuvent être ajoutées progressivement dans `litellm/config.yaml` (voir [Config](https://docs.litellm.ai/docs/proxy/configs)) sans redéploiement lourd.
