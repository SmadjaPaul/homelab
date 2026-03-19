# Homelab Roadmap

> Objectif : Homelab sécurisé où je peux facilement onboarder mes amis et de nouvelles apps.
> Mis à jour : 2026-03-16

---

## Légende

- ✅ Terminé
- 🔴 Bloquant / En cours (priorité immédiate)
- 🟡 Important (prochain sprint)
- 🟢 Nice to have

---

## Infrastructure & Stabilité

| Statut | Item | Notes |
|--------|------|-------|
| ✅ | Architecture multi-stack Pulumi (k8s-core → k8s-storage → k8s-apps) | |
| ✅ | Cloudflare Tunnel Zero Trust (aucun port ouvert) | |
| ✅ | Doppler secrets management + fail-fast validation | |
| ✅ | CloudNativePG cluster partagé (homelab-db, 2×50Gi) | 2 instances HA |
| ✅ | Redis partagé (2Gi oci-bv) | |
| ✅ | CSI drivers (local-path, hetzner-smb) | |
| ✅ | Monitoring : Prometheus → Grafana Cloud + Loki/Promtail | |
| ✅ | S3 backups OCI (velero-backups, homelab-db-backups) | Buckets créés |
| 🔴 | **DiskPressure fix** | Spec: `specs/wip/disk-pressure-fix.md` |
| 🟡 | Supprimer les tolerations disk-pressure (workarounds) | Après fix DiskPressure |
| 🟡 | Alerting (Alertmanager actuellement désactivé) | Grafana Cloud alerts ? |
| 🟡 | Velero opérationnel (bucket existe, opérateur déployé ?) | À vérifier |
| 🟢 | Node secondaire / HA (CNPG 1→2 instances, multi-node) | Coût OCI |
| 🟡 | Health probes pour apps critical tier (authentik, vaultwarden) | Aucune probe actuellement |
| 🟡 | Resource limits pour toutes les apps | Seul vaultwarden a des limits |
| 🟡 | Database backup pour vaultwarden et paperless-ngx | Seul authentik a database_backup |
| 🟡 | Redis authentification (actuellement auth: false) | Accessible sans auth |

---

## Sécurité

| Statut | Item | Notes |
|--------|------|-------|
| ✅ | Authentik IdP + Proxy Outpost | auth.smadja.dev |
| ✅ | SSO par défaut pour toutes les apps protégées | |
| ✅ | NetworkPolicies via NetworkPolicyBuilder | |
| ✅ | External Secrets Operator (sync Doppler → K8s) | |
| ✅ | cert-manager (TLS automatique) | |
| 🔴 | **LDAP bind password en clair dans apps.yaml** | Navidrome, ligne ~657. Migrer vers Doppler |
| 🟡 | slskd : `SLSKD_NO_AUTH: "true"` + mode protected | Quiconque passe Authentik accède à tout |
| 🟡 | Audit des secrets dans git (gitleaks) | Pre-commit configuré mais vérifier historique |
| 🟢 | Politique de rotation des secrets | |
| 🔴 | **Secrets hardcodés dans le code** | Spec: `specs/wip/hardcoded-secrets-cleanup.md` |
| 🟡 | Images Docker non pinnées (:latest) | En cours de fix |
| 🟡 | Security contexts incomplets (runAsNonRoot manquant) | |
| 🟡 | node_maintenance.py privileged: true | À redesign |

---

## SSO & Onboarding Utilisateurs

| Statut | Item | Notes |
|--------|------|-------|
| ✅ | Navidrome : Header auth + auto-création | `ND_REVERSEPROXYAUTOCREATE: true` |
| ✅ | Vaultwarden : OIDC + auto-création | SSO natif Bitwarden |
| ✅ | Audiobookshelf : OIDC + auto-création | |
| ✅ | OwnCloud : OIDC + auto-création | `PROXY_AUTOPROVISION_ACCOUNTS: true` |
| ✅ | Paperless-ngx : Header + auto-création | `HTTP_REMOTE_USER_AUTH_ALLOW_SIGNUPS: true` |
| 🔴 | **Open-WebUI : SSO broken** | Passer en `provisioning.method: oidc` |
| 🟡 | Authentik enrollment flow (invitation par email) | Pour onboarder les amis sans intervention manuelle |
| 🟡 | Guide d'onboarding ami (quelle URL, comment se connecter) | `docs/ONBOARDING.md` à créer |
| 🟡 | Groupe Authentik "friends" avec accès restreint | Admins vs Users vs Friends |
| 🟡 | Navidrome : accès ami en read-only (bibliothèque partagée) | |
| 🟡 | Open-WebUI : modèles LLM gérés uniquement par admin | `SHOW_ADMIN_DETAILS: false` déjà fait |
| 🟢 | Self-service portal pour demande d'accès | Authentik Enrollment + Approval Flow |

---

## Applications

| Statut | Item | Notes |
|--------|------|-------|
| ✅ | Homepage (dashboard) | home.smadja.dev |
| ✅ | Authentik | auth.smadja.dev |
| ✅ | Vaultwarden | vault.smadja.dev |
| ✅ | Navidrome | music.smadja.dev |
| ✅ | Slskd | soulseek.smadja.dev |
| ✅ | Audiobookshelf | audiobooks.smadja.dev |
| ✅ | OwnCloud (OCIS) | cloud.smadja.dev |
| ✅ | Paperless-ngx | paperless.smadja.dev |
| ✅ | Open-WebUI | ai.smadja.dev (SSO à corriger) |
| ✅ | Envoy AI Gateway | Proxy LLM interne |
| 🟡 | Grafana (exposé en externe ?) | Actuellement internal uniquement |
| 🟢 | Jellyfin ou Plex | Streaming vidéo pour les amis |
| 🟢 | Mealie | Gestion de recettes (partageable avec amis) |
| 🟢 | Immich | Photos (alternative Google Photos) |

---

## Developer Experience & SDD

| Statut | Item | Notes |
|--------|------|-------|
| ✅ | apps.yaml source de vérité | |
| ✅ | Pre-commit hooks (gitleaks, ruff, yamllint) | |
| ✅ | Tests statiques + dynamiques (pytest) | |
| ✅ | Structure SDD (specs/, _template.md) | Ajouté 2026-03-16 |
| ✅ | kubernetes-pulumi/CLAUDE.md | Contexte Claude Code |
| ✅ | scripts/update-context.py | Sync SERVICE-CATALOG depuis apps.yaml |
| 🟡 | Mettre à jour SERVICE-CATALOG.md (actuellement stale) | Lancer `update-context.py` |
| 🟡 | CNPG backup opérationnel (tester un restore) | Bucket créé, pas testé |
| 🟢 | CI/CD (GitHub Actions pulumi preview sur PR) | Mode dev local pour l'instant |
| 🟡 | Supprimer dead code identifié (mail_dns.py, setup_identities, etc.) | En cours |
| 🟡 | Simplifier adapter pattern (over-engineering) | 5 sous-classes pour des diffs mineurs |
| 🟡 | Tests health probes, resource limits, backup DB | Gaps identifiés |

---

## Backlog Specs SDD

Specs à créer dans `specs/wip/` quand le moment vient :

| Spec | Priorité | Description |
|------|----------|-------------|
| `open-webui-sso.md` | 🔴 | Corriger SSO Open-WebUI (header → OIDC) |
| `navidrome-ldap-secret.md` | 🔴 | Migrer LDAP bind password vers Doppler |
| `authentik-enrollment.md` | 🟡 | Flow invitation ami par email |
| `grafana-expose.md` | 🟢 | Exposer Grafana en externe avec Authentik |
| `velero-test.md` | 🟡 | Valider que Velero fonctionne (restore test) |
| `friend-access-groups.md` | 🟡 | Groupes Authentik admins/users/friends |
| `hardcoded-secrets-cleanup.md` | 🔴 | Migrer tous les secrets hardcodés vers Doppler |
| `health-probes.md` | 🟡 | Ajouter health probes aux apps critical tier |
| `resource-limits.md` | 🟡 | Ajouter resource limits à toutes les apps |
