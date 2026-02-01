# Proxmox — Créer un utilisateur et un API Token pour Terraform

Ce guide permet de créer un utilisateur Proxmox dédié et un API Token pour que Terraform puisse gérer les VMs/LXC sans mot de passe.

---

## Option A — Tout depuis le Shell Proxmox

À exécuter dans le **Shell** (nœud **pve** → **Shell**) ou en SSH.

### 1. Créer le rôle (droits Terraform)

```bash
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.Audit Datastore.AllocateTemplate Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt"
```

### 2. Créer l’utilisateur

```bash
pveum user add terraform-prov@pve --comment "Terraform API"
```

### 3. Donner le rôle à l’utilisateur sur le Datacenter

```bash
pveum aclmod / -user terraform-prov@pve -role TerraformProv
```

### 4. Créer l’API Token

Le secret est affiché **une seule fois**. Copie-le tout de suite.

```bash
pveum user token add terraform-prov@pve terraform --privsep=0
```

La sortie contient une ligne du type `value: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` : c’est le **secret** à mettre dans `pm_api_token_secret`.

Si la commande n’existe pas ou échoue (selon la version Proxmox), crée le token depuis l’**interface web** (Option B, étape 4).

### 5. Vérifier

```bash
pveum user list
pveum acl list
```

---

## Option B — Interface web (Datacenter → Permissions)

### 1. Créer le rôle

- **Datacenter** → **Permissions** → **Roles** → **Create**
- **Role ID** : `TerraformProv`
- **Privileges** : cocher au minimum
  `Datastore.AllocateSpace`, `Datastore.Audit`, `Sys.Audit`, `Sys.Console`, `Sys.Modify`,
  `VM.Allocate`, `VM.Audit`, `VM.Clone`, `VM.Config.*`, `VM.Migrate`, `VM.Monitor`, `VM.PowerMgmt`,
  `Pool.Allocate`, `Datastore.AllocateTemplate`
- **Create**

### 2. Créer l’utilisateur

- **Datacenter** → **Permissions** → **Users** → **Add**
- **User** : `terraform-prov`
- **Realm** : `Linux PAM standard` (ou `Proxmox VE authentication server`)
- **Comment** : `Terraform API`
- **Add**

### 3. Donner le rôle à l’utilisateur

- **Datacenter** → **Permissions** → **Permissions** (onglet ACL)
- **Add** → **User** : `terraform-prov@pve`, **Role** : `TerraformProv`, **Path** : `/`
- **Add**

### 4. Créer l’API Token

- **Datacenter** → **Permissions** → **Users** → clic sur **terraform-prov@pve**
- Onglet **API Tokens** → **Add**
- **Token ID** : `terraform`
- **Add** → le **secret** s’affiche **une seule fois** : copie-le et garde-le (ex. dans ton gestionnaire de mots de passe).

L’identifiant du token est : **terraform-prov@pve!terraform** (à mettre dans `pm_api_token_id`).

---

## Remplir Terraform

Dans ton repo, copie l’exemple et remplis avec les vraies valeurs :

```bash
cd terraform/proxmox
cp terraform.tfvars.example terraform.tfvars
```

Édite `terraform.tfvars` (ne pas commiter ce fichier) :

```hcl
pm_api_url          = "https://192.168.68.51:8006/"
pm_api_token_id     = "terraform-prov@pve!terraform"
pm_api_token_secret = "le-secret-copié-à-l-étape-4"
pm_insecure         = true
pm_node_name        = "pve"
pm_storage_vm       = "tank-vm"
pm_storage_iso      = "tank-iso"
```

Pour les VMs rapides (NVMe), utilise `pm_storage_vm = "nvme-vm"` dans la ressource VM concernée ou une variable dédiée.

Tester la connexion :

```bash
terraform init
terraform plan
```

Si `terraform plan` affiche les nœuds (data source) sans erreur, l’API Token est bon.
