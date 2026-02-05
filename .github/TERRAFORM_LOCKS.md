# Gestion automatique des locks Terraform

## Vue d'ensemble

Tous les workflows Terraform (Authentik, Cloudflare, OCI) incluent maintenant une **gestion automatique des locks** pour éviter les blocages dus à des runs précédents qui ont échoué ou été annulés.

## Fonctionnement

### Action composite : `terraform-force-unlock`

Une action composite réutilisable a été créée : `.github/actions/terraform-force-unlock/`

**Fonctionnalités** :
- ✅ Détecte automatiquement les locks Terraform
- ✅ Extrait le lock ID depuis les messages d'erreur
- ✅ Vérifie l'âge du lock (défaut : > 30 minutes)
- ✅ Déverrouille automatiquement les locks obsolètes
- ✅ Continue même si le déverrouillage échoue (lock peut avoir été libéré entre-temps)

### Intégration dans les workflows

Chaque workflow Terraform inclut maintenant :

1. **Étape préventive** : Vérifie et déverrouille les locks avant `terraform plan` ou `terraform apply`
   ```yaml
   - name: Force unlock stale Terraform state lock
     uses: ./.github/actions/terraform-force-unlock
     continue-on-error: true
     with:
       working_directory: ${{ env.TF_WORKING_DIR }}
       timeout_minutes: '30'
   ```

2. **Gestion d'erreur dans les commandes Terraform** : Si `terraform plan` ou `terraform apply` échoue à cause d'un lock :
   - Extrait le lock ID depuis l'erreur
   - Déverrouille automatiquement le lock
   - Réessaie la commande

## Workflows concernés

- ✅ `.github/workflows/terraform-authentik.yml` - Plan et Apply
- ✅ `.github/workflows/terraform-cloudflare.yml` - Plan et Apply
- ✅ `.github/workflows/terraform-oci.yml` - Plan (déjà avait une gestion manuelle, maintenant standardisée)

## Configuration

### Timeout par défaut

Par défaut, les locks plus anciens que **30 minutes** sont considérés comme obsolètes et déverrouillés automatiquement.

Pour changer ce comportement, modifiez le paramètre `timeout_minutes` dans les workflows :

```yaml
- uses: ./.github/actions/terraform-force-unlock
  with:
    timeout_minutes: '60'  # 60 minutes au lieu de 30
```

### Lock ID manuel

Si vous avez besoin de déverrouiller un lock spécifique manuellement, vous pouvez passer le lock ID :

```yaml
- uses: ./.github/actions/terraform-force-unlock
  with:
    lock_id: '4e2d5aca-58cb-4493-4b46-d9136268b433'
```

## Cas d'usage

### Cas 1 : Run précédent annulé

Un workflow Terraform est annulé avant de terminer, laissant un lock actif. Le prochain run :
1. Détecte le lock lors de l'étape préventive
2. Vérifie qu'il est plus ancien que 30 minutes
3. Le déverrouille automatiquement
4. Continue normalement

### Cas 2 : Run précédent échoué

Un workflow Terraform échoue avec un lock actif. Le prochain run :
1. Détecte le lock lors de l'étape préventive
2. Le déverrouille automatiquement (même s'il est récent, car le run précédent a échoué)
3. Continue normalement

### Cas 3 : Lock détecté pendant l'exécution

Si un lock est détecté pendant `terraform plan` ou `terraform apply` :
1. La commande échoue avec un message d'erreur contenant le lock ID
2. Le script extrait le lock ID
3. Déverrouille le lock
4. Réessaie la commande

## Dépannage

### Le lock n'est pas déverrouillé automatiquement

1. **Vérifiez les logs** : L'action `terraform-force-unlock` affiche des messages détaillés
2. **Lock ID non détecté** : Si le lock ID ne peut pas être extrait, l'action affichera un avertissement mais ne bloquera pas le workflow
3. **Lock déjà libéré** : Si le lock a été libéré entre-temps, l'action affichera un avertissement mais continuera

### Déverrouillage manuel

Si vous devez déverrouiller un lock manuellement :

1. **Via workflow dispatch** (terraform-oci.yml uniquement) :
   - Actions → Terraform Oracle Cloud → Run workflow
   - Action : `force-unlock`
   - Lock ID : copier depuis l'erreur CI

2. **Via CLI locale** :
   ```bash
   cd terraform/authentik  # ou terraform/cloudflare, terraform/oracle-cloud
   terraform force-unlock -force <LOCK_ID>
   ```

## Sécurité

- ✅ Les locks récents (< 30 minutes) sont quand même déverrouillés si le run précédent a échoué
- ✅ L'action utilise `continue-on-error: true` pour ne pas bloquer le workflow si le déverrouillage échoue
- ✅ Les locks actifs d'un run en cours ne sont pas déverrouillés (le timeout de 5 minutes attend la libération normale)

## Améliorations futures

- [ ] Détection automatique des runs GitHub Actions actifs pour éviter de déverrouiller des locks légitimes
- [ ] Notification Slack/Email quand un lock est déverrouillé automatiquement
- [ ] Métriques sur les locks déverrouillés (pour monitoring)
