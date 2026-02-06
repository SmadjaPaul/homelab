# ✅ Connexion SSH Rétablie

**Date**: 2026-02-06
**Statut**: Secrets GitHub corrigés ✅

---

## ✅ Actions Effectuées

1. **Nouvelle paire de clés SSH générée**
   - Type: ed25519
   - Privée: `~/.ssh/oci_mgmt_key_20260206_110015`
   - Publique: `~/.ssh/oci_mgmt_key_20260206_110015.pub`

2. **Secrets GitHub mis à jour**
   - ✅ `SSH_PUBLIC_KEY` (clé publique valide)
   - ✅ `OCI_MGMT_SSH_PRIVATE_KEY` (clé privée)

3. **Scripts créés**
   - `scripts/fix-ssh-secret.sh` - Correction rapide des secrets SSH
   - `scripts/update-oci-vault-ssh-key.sh` - Mise à jour OCI Vault

---

## 🎯 Prochaines Étapes

### Étape 1: Tester le Workflow Terraform (VALIDATION)

**Via GitHub Actions UI**:
1. Aller sur: https://github.com/SmadjaPaul/homelab/actions
2. Sélectionner: **"Terraform Oracle Cloud"**
3. Cliquer: **"Run workflow"**
4. Paramètres:
   - **Action**: `plan`
   - **Environment**: `development`
   - **Rotate SSH key**: `false` (déjà fait)
5. Cliquer: **"Run workflow"**

**Résultat attendu**: Le workflow doit passer la validation `SSH_PUBLIC_KEY` ✅

---

### Étape 2: Créer les Ressources OCI (si le vault n'existe pas)

Si le workflow `plan` fonctionne, créer les ressources:

**Via GitHub Actions UI**:
1. **"Terraform Oracle Cloud"** → **"Run workflow"**
2. Paramètres:
   - **Action**: `apply`
   - **Environment**: `production`
   - **Rotate SSH key**: `false`
3. Cliquer: **"Run workflow"**

**Ce qui sera créé**:
- VCN (réseau virtuel)
- Subnets
- Security Lists
- OCI Vault (pour les secrets)
- Secrets dans le vault (y compris `homelab-oci-mgmt-ssh-private-key`)
- VMs (si configurées)

---

### Étape 3: Mettre à jour OCI Vault (si le vault existe déjà)

Si le vault existe déjà mais avec une ancienne clé:

**Option A: Via le script local** (si OCI CLI configuré):
```bash
# Définir le compartment ID si nécessaire
export OCI_COMPARTMENT_ID="ocid1.compartment.oc1..xxxxx"

# Mettre à jour le vault
./scripts/update-oci-vault-ssh-key.sh
```

**Option B: Via le workflow GitHub Actions**:
1. **"Rotate OCI SSH key"** → **"Run workflow"**
   - Génère de nouvelles clés et met à jour GitHub + OCI Vault automatiquement
   - ⚠️ Note: Cela génère de NOUVELLES clés (différentes de celles créées localement)

**Option C: Manuellement via OCI Console**:
1. Aller sur: https://cloud.oracle.com/vault/secrets
2. Trouver: `homelab-oci-mgmt-ssh-private-key`
3. Mettre à jour avec le contenu de: `~/.ssh/oci_mgmt_key_20260206_110015`

---

## 🔍 Vérification

### Vérifier les secrets GitHub:
```bash
gh secret list --repo SmadjaPaul/homelab | grep -E "SSH_PUBLIC_KEY|OCI_MGMT_SSH"
```

### Vérifier le format de la clé publique:
```bash
# Doit afficher une ligne commençant par "ssh-ed25519" ou "ssh-rsa"
gh api repos/SmadjaPaul/homelab/actions/secrets/SSH_PUBLIC_KEY 2>/dev/null || echo "Secret non accessible via API (normal)"
```

### Tester localement (si Terraform configuré):
```bash
cd terraform/oracle-cloud
terraform init
terraform plan
# Vérifier qu'il n'y a pas d'erreur sur SSH_PUBLIC_KEY
```

---

## 📋 Checklist de Validation

- [x] Secrets GitHub mis à jour (`SSH_PUBLIC_KEY`, `OCI_MGMT_SSH_PRIVATE_KEY`)
- [ ] Workflow Terraform `plan` passe sans erreur
- [ ] OCI Vault créé (via `terraform apply` ou existe déjà)
- [ ] Secret OCI Vault `homelab-oci-mgmt-ssh-private-key` mis à jour
- [ ] Workflow Terraform `apply` fonctionne
- [ ] VMs OCI créées avec la nouvelle clé publique dans `authorized_keys`

---

## 🚨 En Cas de Problème

### Erreur: "SSH_PUBLIC_KEY must be the PUBLIC key"
- Vérifier que le secret GitHub contient bien une clé publique (une ligne, commence par `ssh-`)
- Réexécuter: `./scripts/fix-ssh-secret.sh --generate-new`

### Erreur: "Secret not found in OCI Vault"
- Le vault n'existe pas encore → Créer via `terraform apply`
- Ou le nom du secret est différent → Vérifier dans `terraform/oracle-cloud/vault-secrets.tf`

### Erreur: "Permission denied (publickey)" sur les VMs
- La clé privée dans OCI Vault ne correspond pas à la clé publique dans Terraform
- Vérifier que `SSH_PUBLIC_KEY` (GitHub) = clé publique de la paire
- Vérifier que `homelab-oci-mgmt-ssh-private-key` (OCI Vault) = clé privée de la même paire

---

## 📚 Références

- [Plan de stabilisation](STABILIZATION-PLAN.md)
- [Runbook rotation secrets](../../docs-site/docs/runbooks/rotate-secrets.md)
- [Guide gestion secrets](../../docs-site/docs/guides/secrets-management.md)
