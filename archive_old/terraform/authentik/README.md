# Authentik Infrastructure as Code

Configuration Terraform complète pour l'instance Authentik `auth.smadja.dev`.

## Objectifs

- [x] Compte utilisateur `smadja-paul@protonmail.com`
- [x] Service account Terraform avec permissions superuser
- [x] Provider Google OAuth2 pour Social Login
- [x] Configuration complète des applications et providers
- [x] RBAC et permissions pour l'automatisation Terraform

## Structure

```
terraform/authentik/
├── main.tf                    # Configuration principale
├── variables.tf               # Variables de configuration
├── provider.tf                # Provider Authentik
├── terraform.tfvars           # Valeurs de configuration
├── outputs.tf                 # Outputs
└── modules/                   # Sous-modules
    ├── users/                  # Gestion des utilisateurs
    ├── tokens/                 # Gestion des tokens
    ├── apps/                   # Applications et providers
    ├── groups/                 # Gestion des groupes
    ├── policies/               # Gestion des politiques
    ├── bindings/               # Liaisons
    └── flows/                  # Gestion des flows
```

## Configuration requise

### 1. Token API Authentik

Créer un token API dans Authentik UI :
1. Se connecter à `https://auth.smadja.dev`
2. Aller dans `Admin → Token`
3. Cliquer sur `Create Token`
4. Copier le token généré

### 2. Configuration Google OAuth2

Configurer Google OAuth2 dans la Google Cloud Console :
1. Aller sur `https://console.cloud.google.com/apis/credentials`
2. Créer un ID client OAuth2
3. Ajouter les redirect URIs :
   - `https://auth.smadja.dev/complete/google-oauth2/`
   - `http://localhost:8000/complete/google-oauth2/` (pour le développement)
4. Copier l'ID client et le secret

## Utilisation

### Initialisation

```bash
# Se placer dans le répertoire
cd /Users/paul/Developer/Perso/homelab/terraform/authentik

# Initialiser Terraform
terraform init

# Configurer le token API (recommandé)
export AUTHENTIK_URL="https://auth.smadja.dev"
export AUTHENTIK_TOKEN="votre-token-api"

# Alternative : décommenter dans terraform.tfvars
# authentik_token = "votre-token-api"
```

### Déploiement

```bash
# Planifier les changements
terraform plan

# Appliquer les changements
terraform apply

# Confirmer avec "yes" lorsque demandé
```

### Outputs

Après le déploiement, les outputs suivants seront disponibles :
- `terraform_token_key` : Clé du token Terraform (superuser)
- `google_oauth2_provider_id` : ID du provider Google OAuth2
- `smadja_paul_user_id` : ID de l'utilisateur Paul

## Permissions

### Service Account Terraform

- **Nom** : `terraform-service`
- **Type** : `service_account`
- **Permissions** : Superuser (accès total à l'API)
- **Usage** : Automation Terraform/CI-CD

### Utilisateur Paul

- **Email** : `smadja-paul@protonmail.com`
- **Groupes** : `admin`, `family-validated`
- **Mot de passe** : `PaulHomelab2026!` (bcrypt hashé)

## Google OAuth2

- **Provider** : Google OAuth2
- **Mode** : `user_email`
- **Validité** : 1 heure (access), 30 jours (refresh)
- **Redirect URI** : `https://auth.smadja.dev/complete/google-oauth2/`

## Notes

1. **Sécurité** : Le token API ne doit jamais être commité
2. **Variables** : Utiliser des variables d'environnement pour les secrets
3. **Mises à jour** : Les slugs des flows peuvent varier selon la version d'Authentik
4. **Développement** : Le redirect URI localhost est disponible pour le développement

## Dépannage

### Token API non reconnu
```bash
# Vérifier le token
echo $AUTHENTIK_TOKEN

# Tester la connexion
curl -H "Authorization: Token $AUTHENTIK_TOKEN" https://auth.smadja.dev/api/v3/health
```

### Google OAuth2 ne fonctionne pas
```bash
# Vérifier les redirect URIs dans Google Cloud Console
# Vérifier que le provider est bien créé
terraform state list | grep google_oauth2

# Vérifier les logs Authentik
# Admin → Logs → Provider OAuth2
```

### Permissions insuffisantes
```bash
# Le service account Terraform a les permissions superuser
# Si vous avez besoin de permissions spécifiques, modifier le module tokens
```

## Maintenance

### Mettre à jour le mot de passe
1. Modifier le hash bcrypt dans `variables.tf:102`
2. Re-déployer avec `terraform apply`

### Ajouter de nouveaux utilisateurs
1. Ajouter à la liste `authentik_users` dans `variables.tf`
2. Re-déployer

### Mettre à jour Google OAuth2
1. Mettre à jour les variables dans `terraform.tfvars`
2. Re-déployer
