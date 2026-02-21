# Auth0 Infrastructure as Code

Configuration Terraform pour le nouveau provider d'identité Cloudflare Access : Auth0.

## Objectifs

- [x] Créer application OIDC pour Cloudflare Zero Trust
- [x] Mettre en place les rôles basiques (Admin)
- [x] Exporter les IDs et Secrets dans Doppler de façon sécurisée

## Structure

```
terraform/auth0/
├── main.tf                    # Application OIDC Auth0 & Rôles
├── variables.tf               # Variables de configuration
├── provider.tf                # Provider Auth0
└── outputs.tf                 # Exports
```

## Déploiement

### 1. Variables préalables (Doppler)

Assurez-vous que les variables suivantes sont configurées dans Doppler (`auth0` project) :
- `AUTH0_DOMAIN` (ex: `tenant.eu.auth0.com`)
- `AUTH0_CLIENT_ID` (Client M2M avec droits API Management)
- `AUTH0_CLIENT_SECRET` (Secret du Client M2M)

### 2. Initialisation

```bash
cd /Users/paul/Developer/Perso/homelab/terraform/auth0
terraform init
```

### 3. Application

```bash
terraform plan
terraform apply
```

Les outputs (`AUTH0_CLOUDFLARE_CLIENT...`) seront automatiquement injectées dans le projet Doppler `homelab` pour nourrir Terraform Cloudflare à l'étape suivante.
