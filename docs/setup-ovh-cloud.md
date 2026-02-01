# Guide : Connexion OVH Cloud (Object Storage + Velero)

Ce guide décrit comment connecter ton homelab à OVH Cloud : créer l’Object Storage (Terraform), puis configurer Velero pour envoyer les backups sur OVH.

## Vue d’ensemble

1. **Créer les identifiants API OVH** (application + consumer key)
2. **Lancer Terraform** (2 applies) → utilisateur S3 + 2 buckets (Velero + archive long terme)
3. **Configurer Velero** pour utiliser le bucket OVH (credentials + URL S3)
4. **(Optionnel)** Tester rclone sur le bucket archive long terme

---

## Étape 1 : Identifiants OVH

### 1.1 Créer une application API

1. Ouvre **[https://eu.api.ovh.com/createToken/](https://eu.api.ovh.com/createToken/)** (connecte-toi à ton compte OVH si besoin).
2. Renseigne :
   - **Description** : par ex. `homelab-terraform`
   - **Validity** : 1 an ou « No expiration » selon ta préférence
3. **Droits** (à cocher) :
   - **GET** sur `/me`
   - **GET, PUT, POST, DELETE** sur `/cloud/*`
4. Clique sur **Generate token**.
5. **Copie immédiatement** les 3 valeurs (tu ne reverras plus le **Application Secret**) :
   - **Application Key**
   - **Application Secret**
   - **Consumer Key**

### 1.2 Récupérer l’ID du projet Public Cloud

1. Va sur **[https://www.ovh.com/manager/public-cloud](https://www.ovh.com/manager/public-cloud)** (ou OVH Control Panel → Public Cloud).
2. Sélectionne ton projet (ou crée un projet Public Cloud si besoin).
3. Ouvre la page du projet : l’**ID du projet** (format UUID, ex. `a1b2c3d4-e5f6-7890-abcd-ef1234567890`) est affiché en haut ou dans les détails. **Copie cet ID** (c’est le `service_name` pour l’API).

### 1.3 Vérifier la région Object Storage

Pour la promo 3 Tio offerts, utilise une région **3-AZ**. Exemples : `gra` (Gravelines), `sbg` (Strasbourg), `eu-west-par` (Paris), `bhs` (Beauharnois). La valeur par défaut dans Terraform est `gra`. Pour **Paris (EU-WEST-PAR)** utilise `s3_region = "eu-west-par"`.

---

## Étape 2 : Terraform (Object Storage)

### 2.1 Fichier de variables

```bash
cd terraform/ovhcloud
cp terraform.tfvars.example terraform.tfvars
```

Ouvre `terraform.tfvars` et remplis (sans commiter ce fichier) :

```hcl
ovh_application_key    = "<Application Key de l'étape 1.1>"
ovh_application_secret = "<Application Secret>"
ovh_consumer_key       = "<Consumer Key>"
ovh_cloud_project_id   = "<ID du projet de l'étape 1.2>"
budget_alert_email     = "ton-email@example.com"
# s3_region = "gra"   # optionnel, gra par défaut
```

Ne mets **pas** encore `ovh_s3_access_key` ni `ovh_s3_secret_key`.

### 2.2 Premier apply (utilisateur + credentials S3)

```bash
cd terraform/ovhcloud

# Backend local pour ce guide (ou supprime backend_override.tf et utilise TFstate.dev)
terraform init
terraform plan   # tu dois voir : ovh_cloud_project_user, ovh_cloud_project_user_s3_credential, ovh_cloud_project_alerting ; pas de bucket
terraform apply
```

À la fin, Terraform affiche les **outputs**. Les credentials S3 sont dans l’output `velero_s3_credentials`.

### 2.3 Récupérer les clés S3

```bash
terraform output -json velero_s3_credentials
```

Tu obtiens quelque chose comme :

```json
{
  "access_key_id": "xxxxxxxx",
  "secret_access_key": "yyyyyyyy"
}
```

Copie `access_key_id` et `secret_access_key`.

### 2.4 Deuxième apply (création des buckets)

Ajoute dans `terraform.tfvars` (en remplaçant par tes vraies valeurs) :

```hcl
ovh_s3_access_key = "<access_key_id>"
ovh_s3_secret_key = "<secret_access_key>"
```

Puis :

```bash
terraform plan   # tu dois voir : aws_s3_bucket.velero[0], aws_s3_bucket.long_term_user_data[0], etc.
terraform apply
```

Après ce second apply, les deux buckets existent (Velero + archive long terme). Les mêmes credentials S3 donnent accès aux deux.

### 2.5 Vérifier les sorties

```bash
terraform output s3_endpoint
terraform output velero_bucket
terraform output long_term_bucket
```

Note l’**endpoint** (ex. `https://s3.gra.io.cloud.ovh.net`) et le **nom du bucket Velero** (ex. `homelab-velero-backups`) : tu en auras besoin pour Velero.

---

## Étape 3 : Configurer Velero pour OVH

Velero utilise le même format de credentials que pour OCI (AWS/S3). Il suffit de changer l’URL S3 et la région.

### 3.1 Données nécessaires

Récupère :

| Donnée | Où la trouver |
|--------|----------------|
| **Bucket** | `terraform output velero_bucket` → champ `name` (ex. `homelab-velero-backups`) |
| **Endpoint S3** | `terraform output s3_endpoint` (ex. `https://s3.gra.io.cloud.ovh.net`) |
| **Région** | Ta `s3_region` (ex. `gra`) |
| **Access Key** | Déjà copié (output `velero_s3_credentials`) |
| **Secret Key** | Déjà copié |

### 3.2 Secret Velero (credentials)

Le secret Kubernetes doit contenir le fichier `cloud` au format AWS (utilisé par le plugin S3) :

```ini
[default]
aws_access_key_id=<ACCESS_KEY_ID>
aws_secret_access_key=<SECRET_ACCESS_KEY>
```

**Option A – Fichier puis création du secret :**

```bash
# Depuis la racine du repo
cd kubernetes/infrastructure/velero

# Créer le fichier cloud (remplacer par tes valeurs)
cat > cloud-ovh << EOF
[default]
aws_access_key_id=TON_ACCESS_KEY_ID
aws_secret_access_key=TON_SECRET_ACCESS_KEY
EOF

# Créer le secret (à chiffrer avec SOPS avant commit si tu versionnes)
kubectl create secret generic velero-credentials \
  --from-file=cloud=cloud-ovh \
  -n velero \
  --dry-run=client -o yaml > credentials-ovh.yaml

# Appliquer
kubectl apply -f credentials-ovh.yaml

# Nettoyer le fichier local (contient des secrets)
rm cloud-ovh
```

**Option B – Éditer le template existant :**

Ouvre `kubernetes/infrastructure/velero/credentials.yaml`, remplace les placeholders par tes clés OVH, puis :

```bash
kubectl apply -f kubernetes/infrastructure/velero/credentials.yaml
```

(Si tu utilises SOPS : édite le fichier chiffré ou recrée le secret puis re-chiffre.)

### 3.3 Configuration Velero (Helm / ArgoCD)

Dans ton application Velero (Helm values), configure le **backupStorageLocation** pour OVH :

- **provider** : `aws` (comme pour OCI, le plugin AWS parle S3)
- **bucket** : nom du bucket Velero (ex. `homelab-velero-backups`)
- **config** :
  - **region** : ta région S3 (ex. `gra`)
  - **s3ForcePathStyle** : `true`
  - **s3Url** : l’endpoint S3 (ex. `https://s3.gra.io.cloud.ovh.net`)

Exemple de bloc `configuration.backupStorageLocation` pour OVH :

```yaml
configuration:
  backupStorageLocation:
    - name: ovh
      provider: aws
      bucket: homelab-velero-backups
      default: true
      config:
        region: gra
        s3ForcePathStyle: true
        s3Url: https://s3.gra.io.cloud.ovh.net
```

Adapte `bucket`, `region` et `s3Url` si tu as changé `s3_region` ou le nom du bucket dans Terraform.

Tu dois aussi :
- mettre **defaultBackupStorageLocation** et **defaultVolumeSnapshotLocations** sur `ovh` (ou le nom que tu donnes à ce storage),
- laisser **volumeSnapshotLocation** en cohérence (même région / même provider si tu utilises des snapshots ; pour Restic, le stockage suffit).

Référence : `kubernetes/infrastructure/velero/application.yaml` (remplace la config OCI par celle ci‑dessus si tu bascules entièrement sur OVH).

### 3.4 (Optionnel) Basculer l’application Velero sur OVH

Si tu veux que Velero utilise **uniquement** OVH (plus OCI), modifie `kubernetes/infrastructure/velero/application.yaml` :

- Dans `configuration.backupStorageLocation` : remplacer la config OCI par la config OVH ci‑dessus.
- Dans `configuration.volumeSnapshotLocation` : pour OVH Object Storage seul (sans snapshot OVH), tu peux garder un provider `aws` avec la même région, ou désactiver les volume snapshots et ne garder que Restic.
- Mettre à jour les schedules pour utiliser le `storageLocation` OVH (ex. `ovh`).
- S’assurer que le secret `velero-credentials` contient bien les clés OVH (étape 3.2).

Puis sync ArgoCD ou `helm upgrade` selon ta façon de déployer.

### 3.5 Vérifier la connexion

```bash
# Si le namespace velero existe déjà
kubectl get pods -n velero

# Après déploiement, lister les backups (doit parler à OVH)
velero backup get
```

Si tout est bon, tu peux lancer un backup de test :

```bash
velero backup create test-ovh --wait
velero backup get
```

---

## Étape 4 (optionnel) : Archive long terme et rclone

Pour le bucket **archive long terme** (données ZFS/Nextcloud « à ne pas perdre »), tu utilises les **mêmes credentials** que pour Velero. Exemple rclone :

```bash
rclone config
# type = s3
# provider = Other
# endpoint = https://s3.gra.io.cloud.ovh.net
# access_key_id / secret_access_key = ceux de terraform output velero_s3_credentials
```

Bucket à cibler : `homelab-user-data-archive` (ou la valeur de `long_term_bucket_name`). Détails et préfixes dans [terraform/ovhcloud/LONG_TERM_BACKUP.md](../terraform/ovhcloud/LONG_TERM_BACKUP.md).

---

## Récap

| Étape | Action |
|-------|--------|
| 1 | Créer token API OVH + noter l’ID projet Public Cloud |
| 2 | `terraform/ovhcloud` : `terraform.tfvars` → 1er apply → récupérer S3 credentials → 2e apply |
| 3 | Créer le secret Kubernetes `velero-credentials` avec les clés OVH |
| 4 | Configurer Velero (backupStorageLocation + config s3Url/region/bucket) et déployer |
| 5 | Tester avec `velero backup create test-ovh --wait` et `velero backup get` |

En cas de souci : vérifier que `terraform.tfvars` n’est pas commité, que les secrets Velero sont bien appliqués dans le namespace `velero`, et que l’URL S3 et la région correspondent à ta config Terraform (`s3_region`, `s3_endpoint`).
