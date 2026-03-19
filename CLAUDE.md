# Agent Instructions

## Pourquoi ce projet
Multi-cluster Kubernetes homelab géré par Pulumi (Python). Traffic via cloudflared (Cloudflare Tunnel). Secrets gérés par uv en local.

## Carte du repo
```
.
├── CLAUDE.md                    # Instructions (ce fichier)
├── docs/                        # Documentation
├── kubernetes-pulumi/           # Infrastructure K8s (Pulumi Python)
│   ├── apps.yaml                # Single source of truth (apps, buckets, identities)
│   ├── k8s-core/                # Phase 1: Namespaces, CRDs, Operators
│   ├── k8s-storage/             # Phase 2: Storage, Databases, S3
│   ├── k8s-apps/                # Phase 3: Applications
│   └── shared/                  # Code partagé (utils, apps, storage)
│       ├── apps/adapters/       # Adapters pour Helm Values
│       ├── apps/common/         # Registries Kubernetes, Storage, Authentik
│       └── networking/          # Modules réseaux (MailDnsManager)
├── terraform/                   # Infra cloud (OCI, Hetzner)
├── scripts/                     # Scripts utilitaires
└── .opencode/                   # Contexte agents IA
```

## Workflow SDD (Spec-Driven Development)

Pour toute tâche non triviale, suivre ce workflow :
1. **Spec** → Créer `specs/wip/<feature>.md` (copier `specs/_template.md`)
2. **Plan** → Demander à Claude de générer un plan SANS coder
3. **Validation** → Approuver le plan avant toute implémentation
4. **Impl** → Implémenter étape par étape
5. **Review** → Vérifier les critères d'acceptance de la spec

## Règles d'or

1. **Secrets dans Doppler uniquement** - Jamais de secrets en dur
2. **Tout passe par Pulumi** - Pas de `kubectl apply` direct
3. **apps.yaml = source de vérité** - Définir les apps en YAML, pas en Python
4. **Mode dev local** - Pas de CI/CD pour l'instant
5. **Déploiement séquentiel** - k8s-core → k8s-storage → k8s-apps

## Architecture détaillée
- **Kubernetes**: Pulumi Python (OCI + Hetzner)
- **Traffic**: Cloudflare Tunnel (cloudflared)
- **Auth**: Authentik Outpost via Proxy
- **Secrets**: Doppler (via pulumiverse-doppler)
- **CLI**: `uv` pour gestion des environement python en local

## Contexte spécialisé
- Architecture K8s → `docs/ARCHITECTURE.md`
- Guide LLM complet → `docs/LLM_GUIDE.md`
- Services déployés → `docs/SERVICE-CATALOG.md`
- Réseau/Tunnel → `docs/NETWORKING.md`
- Infra cloud → `terraform/`
- Secrets → `docs/SECRETS.md` + Doppler
- Pulumi (stack-specific) → `kubernetes-pulumi/CLAUDE.md` (auto-chargé)
