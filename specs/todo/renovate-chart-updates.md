# Spec: Renovate pour Mise à Jour Automatique des Charts Helm

## Contexte

Les versions de charts Helm sont hardcodées dans `apps.yaml` (ex: `version: "2025.2.5"` pour Authentik, `version: "0.7.2"` pour Navidrome). Chaque mise à jour nécessite une édition manuelle du fichier, une vérification des changelogs, et un `pulumi up`. Il n'y a aucune notification quand une nouvelle version est disponible.

Sur 10+ apps, cela représente un effort de maintenance significatif et un risque de laisser des versions vulnérables en production.

## Objectif

Les mises à jour de charts Helm sont détectées automatiquement et proposées via des commits ou des notifications, sans intervention manuelle pour la détection.

## Scope

### In scope
- [ ] Configurer Renovate (ou Dependabot) pour scanner `apps.yaml` et détecter les nouvelles versions de charts Helm
- [ ] Créer un `renovate.json` avec un custom manager regex pour le format `apps.yaml`
- [ ] Stratégie de mise à jour par tier :
  - `tier: ephemeral` → auto-commit des patch versions
  - `tier: standard` → notification (issue ou commit séparé)
  - `tier: critical` → notification uniquement, review manuelle obligatoire
- [ ] Grouper les mises à jour mineures dans un seul commit/PR par semaine
- [ ] Supporter les deux sources de charts : repos Helm classiques et OCI registries

### Out of scope
- CI/CD automatique (pas de pipeline pour l'instant — le user fait `make up` manuellement)
- Mise à jour des images Docker (seulement les charts Helm)
- Rollback automatique
- Tests automatiques post-mise à jour

## Contraintes
- Secrets via Doppler uniquement (jamais en dur)
- Pas de CI/CD existant — Renovate devra tourner localement (`npx renovate`) ou via GitHub App
- `apps.yaml` a un format custom — il faut un regex manager, pas le manager Helm natif de Renovate
- Les versions dans `apps.yaml` sont au format `version: "X.Y.Z"` sous le bloc `helm:`

## Critères d'acceptance
- [ ] `renovate.json` est présent à la racine du repo
- [ ] Renovate détecte correctement toutes les versions de charts dans `apps.yaml`
- [ ] Un run local (`npx renovate --dry-run`) montre les mises à jour disponibles
- [ ] Les mises à jour sont proposées sous forme de commits ou branches séparées
- [ ] Les apps `tier: critical` ne sont jamais mises à jour automatiquement

## Fichiers concernés
- `renovate.json` — nouveau : configuration Renovate avec regex manager
- `kubernetes-pulumi/apps.yaml` — aucune modification (Renovate édite les versions in-place)

## Notes / Références
- Renovate regex manager : https://docs.renovatebot.com/modules/manager/regex/
- Format à matcher dans `apps.yaml` :
  ```yaml
  helm:
    chart: authentik
    repo: https://charts.goauthentik.io
    version: "2025.2.5"
  ```
- Alternative : script maison `scripts/check_chart_updates.py` qui interroge les repos Helm et affiche les versions outdated (plus simple, moins automatisé)
