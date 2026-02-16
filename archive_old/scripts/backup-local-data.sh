#!/bin/bash
# Backup script for local data that doesn't survive VM recreation
# Run this daily via cron: 0 2 * * * /opt/oci-core/scripts/backup-local-data.sh

set -e

BACKUP_DIR="/tmp/homelab-backup-$(date +%Y%m%d_%H%M%S)"
OCI_BUCKET="homelab-backups"
RETENTION_DAYS=30

echo "💾 Starting backup: $(date)"
echo "============================"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# 1. Backup Traefik Let's Encrypt certificates
echo "📜 Backing up Traefik certificates..."
if [ -d "/opt/oci-core/data/traefik/letsencrypt" ]; then
    tar czf "$BACKUP_DIR/traefik-certs.tar.gz" -C /opt/oci-core/data/traefik letsencrypt
    echo "✓ Traefik certs backed up"
else
    echo "⚠ Traefik certs directory not found"
fi

# 2. Backup Prometheus data (metrics)
echo "📊 Backing up Prometheus data..."
if [ -d "/opt/oci-core/data/prometheus" ]; then
    # Prometheus needs to be snapshot for consistent backup
    # For now, we'll backup the whole directory (some data may be incomplete)
    tar czf "$BACKUP_DIR/prometheus-data.tar.gz" -C /opt/oci-core/data prometheus
    echo "✓ Prometheus data backed up"
else
    echo "⚠ Prometheus data directory not found"
fi

# 3. Backup Authentik media files
echo "👤 Backing up Authentik media..."
if [ -d "/opt/oci-core/data/authentik/media" ]; then
    tar czf "$BACKUP_DIR/authentik-media.tar.gz" -C /opt/oci-core/data/authentik media
    echo "✓ Authentik media backed up"
else
    echo "⚠ Authentik media directory not found"
fi

# 4. Backup configuration files
echo "⚙️  Backing up configuration files..."
if [ -d "/opt/oci-core/config" ]; then
    tar czf "$BACKUP_DIR/configs.tar.gz" -C /opt/oci-core config
    echo "✓ Configurations backed up"
else
    echo "⚠ Config directory not found"
fi

# 5. Backup Docker Compose and scripts
echo "🐳 Backing up Docker Compose and scripts..."
if [ -f "/opt/oci-core/docker-compose.yml" ]; then
    cp /opt/oci-core/docker-compose.yml "$BACKUP_DIR/"
fi
if [ -d "/opt/oci-core/scripts" ]; then
    tar czf "$BACKUP_DIR/scripts.tar.gz" -C /opt/oci-core scripts
fi
echo "✓ Docker files backed up"

# 6. Create backup manifest
cat > "$BACKUP_DIR/MANIFEST.txt" << EOF
Homelab Backup Manifest
=======================
Date: $(date)
Hostname: $(hostname)

Contents:
- traefik-certs.tar.gz : Let's Encrypt certificates
- prometheus-data.tar.gz : Prometheus metrics data
- authentik-media.tar.gz : Authentik uploaded files
- configs.tar.gz : Service configurations
- docker-compose.yml : Docker Compose file
- scripts.tar.gz : Utility scripts

To restore:
1. Extract backup to /opt/oci-core
2. Ensure permissions are correct
3. Restart services: docker compose up -d
EOF

# 7. Compress everything
echo "📦 Creating final backup archive..."
cd /tmp
FINAL_BACKUP="homelab-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
tar czf "$FINAL_BACKUP" "$(basename $BACKUP_DIR)"

# 8. Upload to OCI Object Storage (if configured)
if command -v oci &> /dev/null; then
    echo "☁️  Uploading to OCI Object Storage..."

    # Check if bucket exists, create if not
    if ! oci os bucket get --name "$OCI_BUCKET" &> /dev/null; then
        echo "Creating backup bucket..."
        oci os bucket create --name "$OCI_BUCKET" --compartment-id "$OCI_COMPARTMENT_ID"
    fi

    # Upload backup
    oci os object put --bucket-name "$OCI_BUCKET" --file "/tmp/$FINAL_BACKUP" --name "backups/$FINAL_BACKUP"
    echo "✓ Backup uploaded to OCI: backups/$FINAL_BACKUP"

    # Cleanup old backups (keep only last $RETENTION_DAYS days)
    echo "🧹 Cleaning up old backups..."
    oci os object list --bucket-name "$OCI_BUCKET" --prefix "backups/homelab-backup-" --query "data[?\"time-created\"<='$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d)']|[*].name" --output table 2>/dev/null | while read -r object; do
        if [ ! -z "$object" ] && [ "$object" != "Name" ]; then
            echo "Deleting old backup: $object"
            oci os object delete --bucket-name "$OCI_BUCKET" --name "$object" --force
        fi
    done
else
    echo "⚠ OCI CLI not found. Backup saved locally: /tmp/$FINAL_BACKUP"
fi

# 9. Cleanup local files
rm -rf "$BACKUP_DIR"
if [ -f "/tmp/$FINAL_BACKUP" ]; then
    rm "/tmp/$FINAL_BACKUP"
fi

echo ""
echo "✅ Backup complete: $(date)"
echo "============================"

# Optional: Send notification (configure webhook if needed)
# curl -X POST "$BACKUP_WEBHOOK_URL" -d "Backup completed: $FINAL_BACKUP"
