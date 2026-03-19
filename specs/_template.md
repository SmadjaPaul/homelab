# Spec: [Titre Court]

## Contexte
<!-- Pourquoi on fait ça ? Quel problème ça résout ? -->

## Objectif
<!-- Une phrase : ce qui doit être vrai quand c'est terminé -->

## Scope

### In scope
- [ ] ...

### Out of scope
- ...

## Contraintes
- Secrets via Doppler uniquement (jamais en dur)
- Définir les apps dans apps.yaml, pas en Python
- Tout passe par Pulumi (pas de kubectl apply direct)
- <!-- Contraintes spécifiques à cette feature -->

## Critères d'acceptance
- [ ] `uv run pulumi preview --stack oci` passe sans erreur
- [ ] `uv run pytest tests/static/ -v` passe
- [ ] <!-- Critères fonctionnels spécifiques -->

## Fichiers concernés
<!-- Liste des fichiers à créer ou modifier -->
- `kubernetes-pulumi/apps.yaml`
- ...

## Notes / Références
<!-- Docs, issues, PRs liées -->
