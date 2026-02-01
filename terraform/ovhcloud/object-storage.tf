# =============================================================================
# OVHcloud Object Storage S3 (3-AZ)
# Promo: 3 premiers Tio/mois offerts jusqu'au 31/01/2026
# =============================================================================

# User dédié Object Storage (rôle objectstore_operator)
resource "ovh_cloud_project_user" "velero" {
  service_name = var.ovh_cloud_project_id
  description  = var.object_storage_user_description
  role_names   = ["objectstore_operator"]
}

# Credentials S3 pour ce user (access_key + secret_key)
resource "ovh_cloud_project_user_s3_credential" "velero" {
  service_name = ovh_cloud_project_user.velero.service_name
  user_id      = ovh_cloud_project_user.velero.id
}

# Bucket S3 (créé via provider AWS avec endpoint OVH)
# Créé seulement quand ovh_s3_access_key/secret_key sont renseignés (après 1er apply ciblé)
locals {
  ovh_s3_credentials_set = (var.ovh_s3_access_key != null && var.ovh_s3_access_key != "") && (var.ovh_s3_secret_key != null && var.ovh_s3_secret_key != "")
}

resource "aws_s3_bucket" "velero" {
  count    = local.ovh_s3_credentials_set ? 1 : 0
  provider = aws.ovh_s3

  bucket = var.velero_bucket_name

  tags = {
    Project     = "homelab"
    Purpose     = "velero-backups"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# Versioning pour sécurité des backups
resource "aws_s3_bucket_versioning" "velero" {
  count    = local.ovh_s3_credentials_set ? 1 : 0
  provider = aws.ovh_s3

  bucket = aws_s3_bucket.velero[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle: suppression des anciens objets (optionnel, pour rester dans le gratuit)
resource "aws_s3_bucket_lifecycle_configuration" "velero" {
  count    = local.ovh_s3_credentials_set ? 1 : 0
  provider = aws.ovh_s3

  bucket = aws_s3_bucket.velero[0].id

  rule {
    id     = "delete-old-backups"
    status = "Enabled"

    filter {
      prefix = "backups/"
    }

    expiration {
      days = 30
    }
  }

  rule {
    id     = "delete-old-restic"
    status = "Enabled"

    filter {
      prefix = "restic/"
    }

    expiration {
      days = 30
    }
  }
}

# Blocage accès public (OVH peut renvoyer 409 sur PutPublicAccessBlock ; on ignore les changements si déjà créé)
resource "aws_s3_bucket_public_access_block" "velero" {
  count    = local.ovh_s3_credentials_set ? 1 : 0
  provider = aws.ovh_s3

  bucket = aws_s3_bucket.velero[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  lifecycle {
    ignore_changes = [block_public_acls, block_public_policy, ignore_public_acls, restrict_public_buckets]
  }
}

# =============================================================================
# Bucket archive long terme – données utilisateur (ZFS, Nextcloud « à ne pas perdre »)
# Mêmes credentials que Velero ; préfixes recommandés : zfs/, nextcloud/, etc.
# =============================================================================

resource "aws_s3_bucket" "long_term_user_data" {
  count    = local.ovh_s3_credentials_set ? 1 : 0
  provider = aws.ovh_s3

  bucket = var.long_term_bucket_name

  tags = {
    Project     = "homelab"
    Purpose     = "user-data-archive"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "long_term_user_data" {
  count    = local.ovh_s3_credentials_set ? 1 : 0
  provider = aws.ovh_s3

  bucket = aws_s3_bucket.long_term_user_data[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle optionnel : si long_term_expiration_days est défini, suppression après N jours
# Sinon (null) : pas d’expiration, données conservées indéfiniment
resource "aws_s3_bucket_lifecycle_configuration" "long_term_user_data" {
  count    = local.ovh_s3_credentials_set && var.long_term_expiration_days != null ? 1 : 0
  provider = aws.ovh_s3

  bucket = aws_s3_bucket.long_term_user_data[0].id

  rule {
    id     = "expire-after-days"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.long_term_expiration_days
    }
  }
}

resource "aws_s3_bucket_public_access_block" "long_term_user_data" {
  count    = local.ovh_s3_credentials_set ? 1 : 0
  provider = aws.ovh_s3

  bucket = aws_s3_bucket.long_term_user_data[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  lifecycle {
    ignore_changes = [block_public_acls, block_public_policy, ignore_public_acls, restrict_public_buckets]
  }
}
