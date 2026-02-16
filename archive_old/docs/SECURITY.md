🔒 Security Configuration

# Configuration Sécurité - Protection Multi-Couches

Ce document explique comment configurer les protections de sécurité pour le projet homelab.

## 🛡️ Couches de Sécurité

### 1. GitHub Repository Settings

#### Branch Protection (Main)
Aller dans Settings > Branches > Add rule pour `main`:

```
✅ Require a pull request before merging
   - Required approvals: 1 minimum (2 recommandé pour Authentik)
   - Dismiss stale PR approvals when new commits are pushed
   - Require review from CODEOWNERS
   - Restrict who can dismiss pull request reviews: @SmadjaPaul

✅ Require status checks to pass before merging
   - Security Scan
   - Terraform Validate

✅ Require conversation resolution before merging

✅ Require signed commits (optionnel mais recommandé)

✅ Include administrators

✅ Restrict who can push to matching branches
   - @SmadjaPaul uniquement
```

#### CODEOWNERS
Le fichier `.github/CODEOWNERS` est déjà configuré pour exiger l'approbation de @SmadjaPaul pour:
- `/terraform/authentik/**` - Toute la configuration Authentik
- `/.github/workflows/**` - Workflows CI/CD
- `/docker/oci-core/**` - Configuration Docker avec secrets

### 2. GitHub Environment Protection

Créer un environment `authentik-production` dans Settings > Environments:

```yaml
# Configuration requise:

Environment name: authentik-production
Protection rules:
  ✅ Required reviewers: 1 (mets ton username)
  ✅ Wait timer: 5 minutes (300 seconds)
  ✅ Deployment branches:
     - Only branches: main
     - No branch protection rules

Deployment protection:
  ✅ Prevent self-review
```

### 3. Security Scan (Automatique)

Le workflow `.github/workflows/security-scan.yml` s'exécute automatiquement sur chaque PR et vérifie:
- ✅ Terraform fmt / validate
- ✅ Checkov security policies
- ✅ Authentik-specific security rules:
  - Pas de création de superuser
  - Pas de modification du compte bootstrap
  - MFA requise pour tous les users
  - Flows d'authentification configurés

### 4. Audit & Monitoring

#### Logs GitHub Actions
- Conservés 90 jours par défaut
- Tous les déploiements Authentik sont logués avec:
  - Timestamp
  - Utilisateur (actor)
  - SHA du commit
  - Changements appliqués

#### Notifications (Optionnel)
Pour ajouter des notifications Slack/Discord, créer un webhook dans Settings > Webhooks et ajouter une étape dans le workflow:

```yaml
- name: Notify on deployment
  uses: slackapi/slack-github-action@v1
  with:
    webhook: ${{ secrets.SLACK_WEBHOOK_URL }}
    message: "Authentik deployment by ${{ github.actor }} - Status: ${{ job.status }}"
```

## 🚨 Actions en cas de compromission

Si tu suspectes que quelqu'un a créé un utilisateur non autorisé:

1. **Immédiatement**:
   ```bash
   # Se connecter en SSH à la VM
   ssh -i ~/.ssh/oci-homelab ubuntu@158.178.210.98

   # Vérifier les utilisateurs récents
   docker exec -it authentik-worker ak export_user --all

   # Révoquer les sessions actives
   docker exec -it authentik-worker ak revoke_sessions --all
   ```

2. **Changer le bootstrap token**:
   - Générer un nouveau token dans l'UI Authentik
   - Mettre à jour le secret `AUTHENTIK_BOOTSTRAP_TOKEN` dans GitHub
   - Redéployer

3. **Auditer les changements**:
   ```bash
   # Voir l'historique Git
   git log --all --full-history -- terraform/authentik/

   # Vérifier qui a déployé
   gh run list --workflow=deploy-stack.yml --limit 10
   ```

## 📋 Checklist de sécurité

- [ ] Branch protection activée sur `main`
- [ ] CODEOWNERS configuré
- [ ] Environment `authentik-production` créé avec reviewers
- [ ] Secrets GitHub bien protégés (pas dans le code)
- [ ] Clé SSH de la VM sécurisée (pas partagée)
- [ ] Audit logs activés dans Authentik UI

## 🔐 Bonnes pratiques

1. **Ne jamais** committer:
   - Tokens Authentik
   - Clés privées SSH
   - Mots de passe
   - Fichiers .env

2. **Toujours**:
   - Faire des PR pour les changements
   - Reviewer son propre code
   - Tester en local avant de push
   - Documenter les changements dans les commits

3. **Rotation régulière**:
   - Changer le bootstrap token tous les 3 mois
   - Rotater les secrets Cloudflare annuellement
   - Vérifier les accès SSH mensuellement

## 🆘 Support

En cas de problème:
1. Vérifier les logs GitHub Actions
2. Consulter l'historique des déploiements
3. Vérifier les utilisateurs dans Authentik UI
4. Contacter @SmadjaPaul (admin)
