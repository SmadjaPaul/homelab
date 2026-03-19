<!-- Context: core/navigation | Priority: critical | Version: 4.0 | Updated: 2026-03-13 -->

# Homelab Context Navigation

Bienvenue dans le projet Homelab de Paul. Voici comment naviguer efficacement.

## Structure Globale

```
.
├── CLAUDE.md                    # Instructions principales
├── docs/                        # Documentation du projet
│   ├── ARCHITECTURE.md          # Architecture Kubernetes & Pulumi (V2)
│   ├── SERVICE-CATALOG.md       # Services déployés
│   ├── NETWORKING.md            # Accès Zero Trust, Cloudflare Tunnel
│   ├── STORAGE.md               # Stratégie stockage (OCI + Hetzner)
│   ├── SECRETS.md               # Gestion secrets (Doppler)
│   └── DEPLOYMENT.md            # Procédures de déploiement
├── .opencode/context/           # Contexte spécialisé agents IA
│   ├── navigation.md            # Ce fichier
│   ├── infrastructure.md        # Cloud, Terraform, Stockage
│   ├── kubernetes.md            # Pulumi, Apps, Flux GitOps
│   └── security_auth.md         # Authentik, Zero Trust
├── kubernetes-pulumi/           # Infrastructure K8s (Pulumi Python)
│   ├── apps.yaml                # Single source of truth (apps, buckets)
│   ├── k8s-core/                # Phase 1: Namespaces, CRDs, Operators
│   ├── k8s-storage/             # Phase 2: Storage, Databases, S3
│   ├── k8s-apps/                # Phase 3: Applications
│   └── shared/                  # Code partagé (BaseApp, Adapters, Registries)
├── terraform/                    # Infra cloud (OCI)
└── scripts/                     # Scripts utilitaires
```

## Routes Rapides

| Besoin | Fichier |
|--------|---------|
| **Comprendre le projet** | `CLAUDE.md` |
| **Architecture** | `docs/ARCHITECTURE.md` |
| **Services déployés** | `docs/SERVICE-CATALOG.md` |
| **Secrets (Doppler)** | `docs/SECRETS.md` |
| **Réseau** | `docs/NETWORKING.md` |
| **Stockage** | `docs/STORAGE.md` |

## Contextes Spécialisés

| Domaine | Contexte |
|---------|----------|
| **Infra & IaC** | `.opencode/context/infrastructure.md` |
| **Kubernetes & Pulumi** | `.opencode/context/kubernetes.md` |
| **Auth & Sécurité** | `.opencode/context/security_auth.md` |

## Principes

1. **Prompting temporaire** → **Structure permanente**
2. **Court, dense, efficace** - 3 choses: pourquoi, carte, règles
3. **apps.yaml = source de vérité** - Définir les apps en YAML, pas en Python
4. **Doppler pour les secrets** - Jamais de secrets en dur
