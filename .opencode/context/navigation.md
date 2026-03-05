<!-- Context: core/navigation | Priority: critical | Version: 3.0 | Updated: 2026-03-05 -->

# Homelab Context Navigation

Bienvenue dans le projet Homelab de Paul. Voici comment naviguer efficacement.

## Structure Globale

```
.
├── CLAUDE.md              # Instructions principales (~30 lignes)
├── docs/                  # Documentation accessible
├── .claude/               # Skills & Hooks pour agents
│   ├── skills/            # Modes experts (code-review, debug, etc.)
│   └── hooks/            # Guardrails (sécurité, GitOps)
├── .opencode/context/     # Contexte spécialisé
│   ├── navigation.md     # Ce fichier
│   ├── infrastructure.md # Cloud, Terraform, Secrets
│   ├── kubernetes.md     # Flux GitOps, K8s
│   └── security_auth.md  # Auth, Zero Trust
├── kubernetes/            # Configs K8s
├── terraform/            # IaC
└── scripts/               # Scripts
```

## Routes Rapides

| Besoin | Fichier |
|--------|---------|
| **Comprendre le projet** | `CLAUDE.md` |
| **Roadmap** | `ROADMAP.md` |
| **Code Review** | `.claude/skills/code-review.md` |
| **Debug** | `.claude/skills/debug.md` |
| **Release** | `.claude/skills/release.md` |
| **Refactor** | `.claude/skills/refactor.md` |
| **Guardrails** | `.claude/hooks/*.md` |
| **Architecture** | `docs/ARCHITECTURE.md` |
| **Secrets** | `docs/SECRETS.md` |
| **Réseau** | `docs/NETWORKING.md` |

## Contextes Spécialisés

| Domaine | Contexte |
|---------|----------|
| **Infra & IaC** | `.opencode/context/infrastructure.md` |
| **Kubernetes & Flux** | `.opencode/context/kubernetes.md` |
| **Auth & Sécurité** | `.opencode/context/security_auth.md` |

## Modules Sensibles (CLAUDE.md locaux)

Ces dossiers ont leur propre contexte local:

- `terraform/auth0/CLAUDE.md` - Config Auth0
- `scripts/CLAUDE.md` - Scripts utilitaires
- `kubernetes/bootstrap/CLAUDE.md` - Bootstrap cluster

## Principes

1. **Prompting temporaire** → **Structure permanente**
2. **Court, dense, efficace** - 3 choses: pourquoi, carte, règles
3. **Guardrails déterministes** - Ce qui doit être bloqué, l'est toujours
4. **Context local** - Instructions là où les pièges apparaissent
