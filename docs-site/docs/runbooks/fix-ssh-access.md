---
sidebar_position: 11
---

# Résoudre les Problèmes d'Accès SSH

Si tu ne peux pas te connecter en SSH à la VM OCI management, voici comment diagnostiquer et résoudre le problème.

## Diagnostic Rapide

Utilise le script de diagnostic :

```bash
./scripts/fix-ssh-access.sh
```

Le script vérifie :
1. ✅ Ton IP publique actuelle
2. ✅ Si le port 22 est accessible
3. ✅ Si ton IP est dans `admin_allowed_cidrs`
4. ✅ La configuration Terraform
5. ✅ La clé SSH

## Causes Courantes

### 1. Ton IP n'est pas dans `admin_allowed_cidrs`

**Symptôme** : `ssh: connect to host ... port 22: Operation timed out`

**Solution** :

```bash
# 1. Récupère ton IP publique
curl https://api.ipify.org

# 2. Ajoute-la à terraform.tfvars
cd terraform/oracle-cloud
nano terraform.tfvars
```

Ajoute ou modifie :
```hcl
admin_allowed_cidrs = ["TON_IP/32"]
```

Puis applique :
```bash
terraform apply
```

**Attendre 1-2 minutes** pour que les règles de sécurité se propagent.

---

### 2. `allow_ssh_from_anywhere` est à `false`

**Solution temporaire** (pour débloquer rapidement) :

```hcl
# terraform.tfvars
allow_ssh_from_anywhere = true
```

```bash
terraform apply
```

⚠️ **Important** : Remets à `false` après avoir ajouté ton IP à `admin_allowed_cidrs`.

---

### 3. La Security List n'est pas attachée au subnet

**Vérification** :

```bash
cd terraform/oracle-cloud
terraform output security_list_ids
```

Si la liste est vide ou ne contient pas `homelab-admin-ssh-sl`, vérifie :

```hcl
# network.tf devrait avoir :
security_list_ids = concat(
  [oci_core_security_list.public.id],
  var.enable_ssh_access ? [oci_core_security_list.admin_ssh[0].id] : []
)
```

---

### 4. fail2ban a bloqué ton IP

Si tu as fait plusieurs tentatives avec un mauvais mot de passe, fail2ban peut avoir bloqué ton IP.

**Solution** :

1. Connecte-toi via OCI Console (Cloud Shell ou autre méthode)
2. Vérifie fail2ban :
   ```bash
   sudo fail2ban-client status sshd
   ```
3. Débloque ton IP :
   ```bash
   sudo fail2ban-client set sshd unbanip TON_IP
   ```

---

### 5. Mauvaise clé SSH

**Vérification** :

```bash
# Vérifie que la clé correspond à celle dans Terraform
ssh-keygen -y -f ~/.ssh/oci_mgmt.pem | diff - <(terraform output -raw ssh_public_key)
```

Si différent, utilise la bonne clé ou mets à jour `ssh_public_key` dans Terraform.

---

## Solution Rapide (Temporaire)

Pour débloquer rapidement l'accès SSH :

```bash
cd terraform/oracle-cloud

# Option 1: Ajouter ton IP
echo 'admin_allowed_cidrs = ["'$(curl -s https://api.ipify.org)'/32"]' >> terraform.tfvars

# Option 2: Autoriser depuis partout (temporaire)
echo 'allow_ssh_from_anywhere = true' >> terraform.tfvars

# Appliquer
terraform apply -auto-approve

# Attendre 1-2 minutes
sleep 120

# Tester SSH
ssh -i ~/.ssh/oci_mgmt.pem ubuntu@$(terraform output -raw management_vm_public_ip)
```

---

## Vérification Post-Correction

```bash
# 1. Vérifie que les règles sont appliquées
terraform output security_list_ids

# 2. Teste la connectivité
nc -zv $(terraform output -raw management_vm_public_ip) 22

# 3. Teste SSH
ssh -i ~/.ssh/oci_mgmt.pem ubuntu@$(terraform output -raw management_vm_public_ip) "echo 'SSH OK'"
```

---

## Prévention

Pour éviter ce problème à l'avenir :

1. **Ajoute ton IP dans `admin_allowed_cidrs`** dès le début
2. **Utilise un VPN** avec IP fixe (optionnel)
3. **Configure un bastion host** dans OCI (plus sécurisé)
4. **Utilise Cloudflare Access** pour l'accès admin (alternative à SSH)

---

## Références

- [OCI Security Lists Documentation](https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/securitylists.htm)
- [Terraform OCI Security List](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_security_list)
