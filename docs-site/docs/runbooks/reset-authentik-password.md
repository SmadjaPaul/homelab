---
sidebar_position: 10
---

# Réinitialiser le mot de passe Authentik

Si tu ne peux plus te connecter à Authentik (`auth.smadja.dev`), voici plusieurs méthodes pour réinitialiser ton mot de passe.

## Méthode 1 : Script automatique (Recommandé)

Utilise le script fourni qui se connecte à la VM et réinitialise le mot de passe :

```bash
# Depuis la racine du repo
./scripts/reset-authentik-password.sh smadja-paul@protonmail.com 'TonNouveauMotDePasse123!'
```

Le script :
1. Récupère l'IP de la VM depuis Terraform
2. Se connecte en SSH
3. Utilise la commande `ak reset_password` d'Authentik
4. Affiche le nouveau mot de passe

## Méthode 2 : Via SSH manuel

Si le script ne fonctionne pas, connecte-toi manuellement à la VM :

```bash
# 1. Récupérer l'IP de la VM
cd terraform/oracle-cloud
terraform output -json | jq -r '.management_vm.value.public_ip'

# 2. Se connecter en SSH
ssh ubuntu@<VM_IP> -i ~/.ssh/oci_mgmt.pem

# 3. Aller dans le répertoire du projet
cd ~/homelab/oci-mgmt

# 4. Réinitialiser le mot de passe
docker compose exec authentik-server ak reset_password \
  --email smadja-paul@protonmail.com \
  --password 'TonNouveauMotDePasse123!'
```

## Méthode 3 : Créer un nouveau compte admin

Si le compte n'existe plus ou est corrompu :

```bash
# Sur la VM
cd ~/homelab/oci-mgmt

# Créer un nouveau superuser
docker compose exec authentik-server ak create_user \
  --email admin@smadja.dev \
  --name "Admin User" \
  --password 'TonNouveauMotDePasse123!' \
  --superuser

# Ajouter l'utilisateur au groupe admin
docker compose exec authentik-server ak shell -c "
from authentik.core.models import User, Group
user = User.objects.get(email='admin@smadja.dev')
admin_group = Group.objects.get(name='authentik Admins')
user.ak_groups.add(admin_group)
user.save()
"
```

## Méthode 4 : Réinitialiser via l'interface web (si accessible)

Si tu as encore accès à l'interface mais pas au compte admin :

1. Va sur `https://auth.smadja.dev/if/flow/initial-setup/`
2. Si c'est la première installation, crée un nouveau compte admin
3. Si un compte existe déjà, utilise la méthode 1 ou 2

## Vérifier que les conteneurs fonctionnent

Avant de réinitialiser, vérifie que les conteneurs Authentik sont bien démarrés :

```bash
# Sur la VM
cd ~/homelab/oci-mgmt
docker compose ps

# Vérifier les logs en cas d'erreur
docker compose logs authentik-server
docker compose logs authentik-worker
```

## Problème : AUTHENTIK_SECRET_KEY a changé

⚠️ **Important** : Si `AUTHENTIK_SECRET_KEY` a changé depuis la création du compte, les données chiffrées dans la base de données peuvent être corrompues.

**Solution** : Il faut soit :
1. Restaurer l'ancien `AUTHENTIK_SECRET_KEY` (dans OCI Vault ou `.env`)
2. Ou réinitialiser complètement Authentik (perte de données) :

```bash
# ⚠️ ATTENTION : Cela supprime toutes les données Authentik !
cd ~/homelab/oci-mgmt
docker compose down -v  # Supprime les volumes
docker compose up -d    # Recrée tout
# Puis va sur https://auth.smadja.dev/if/flow/initial-setup/
```

## Commandes Authentik utiles

```bash
# Lister les utilisateurs
docker compose exec authentik-server ak list_users

# Voir les détails d'un utilisateur
docker compose exec authentik-server ak show_user --email smadja-paul@protonmail.com

# Activer/désactiver un utilisateur
docker compose exec authentik-server ak update_user --email smadja-paul@protonmail.com --is-active true

# Lister les groupes
docker compose exec authentik-server ak list_groups
```

## Prévention

Pour éviter ce problème à l'avenir :

1. **Sauvegarde régulière** de la base PostgreSQL :
   ```bash
   docker compose exec postgres pg_dumpall -U homelab > backup.sql
   ```

2. **Ne jamais changer `AUTHENTIK_SECRET_KEY`** après la première installation

3. **Utiliser un gestionnaire de mots de passe** pour stocker le mot de passe admin

4. **Configurer la récupération de mot de passe** dans Authentik (Settings → Flows → Recovery)
