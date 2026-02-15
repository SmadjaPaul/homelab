#!/bin/bash
# Automated Backup Script for PostgreSQL databases
# Usage: ./backup.sh [service]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Backup function
backup_postgres() {
    local container=$1
    local db=$2
    local user=$3
    local filename="${BACKUP_DIR}/${db}_${DATE}.sql.gz"

    log_info "Backing up ${db} from ${container}..."

    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        docker exec "${container}" pg_dump -U "${user}" "${db}" | gzip > "${filename}"
        log_success "Backup created: ${filename}"

        # Upload to remote storage if configured
        if command -v rclone &> /dev/null && [ -f "${SCRIPT_DIR}/rclone.conf" ]; then
            log_info "Uploading to remote storage..."
            rclone copy "${filename}" remote:homelab-backups/postgres/ --config "${SCRIPT_DIR}/rclone.conf"
            log_success "Upload complete"
        fi
    else
        log_error "Container ${container} not found or not running"
        return 1
    fi
}

# Cleanup old backups
cleanup_backups() {
    log_info "Cleaning up backups older than ${RETENTION_DAYS} days..."
    find "${BACKUP_DIR}" -name "*.sql.gz" -mtime +${RETENTION_DAYS} -delete
    log_success "Cleanup complete"
}

# Main backup logic
case "${1:-all}" in
    all)
        log_info "Starting backup for all services..."

        # Authentik PostgreSQL
        backup_postgres "authentik-postgresql" "authentik" "authentik" || true

        # Comet PostgreSQL (if running)
        if docker ps --format '{{.Names}}' | grep -q "^comet-postgres$"; then
            backup_postgres "comet-postgres" "comet" "comet" || true
        fi

        # Additional services can be added here

        cleanup_backups
        log_success "All backups completed"
        ;;

    authentik)
        backup_postgres "authentik-postgresql" "authentik" "authentik"
        cleanup_backups
        ;;

    comet)
        backup_postgres "comet-postgres" "comet" "comet"
        cleanup_backups
        ;;

    restore)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 restore <backup_file> <container>"
            echo "Example: $0 restore authentik_20240215_120000.sql.gz authentik-postgresql"
            exit 1
        fi

        BACKUP_FILE="${BACKUP_DIR}/$2"
        CONTAINER="$3"

        if [ ! -f "${BACKUP_FILE}" ]; then
            log_error "Backup file not found: ${BACKUP_FILE}"
            exit 1
        fi

        log_warn "This will overwrite the current database. Continue? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Restore cancelled"
            exit 0
        fi

        log_info "Restoring backup to ${CONTAINER}..."
        zcat "${BACKUP_FILE}" | docker exec -i "${CONTAINER}" psql -U authentik -d authentik
        log_success "Restore completed"
        ;;

    list)
        log_info "Available backups:"
        ls -lah "${BACKUP_DIR}"/*.sql.gz 2>/dev/null || echo "No backups found"
        ;;

    *)
        echo "Usage: $0 {all|authentik|comet|restore|list}"
        echo ""
        echo "Commands:"
        echo "  all       - Backup all databases"
        echo "  authentik - Backup Authentik database"
        echo "  comet     - Backup Comet database"
        echo "  restore   - Restore from backup (requires file and container name)"
        echo "  list      - List available backups"
        echo ""
        echo "Examples:"
        echo "  $0 all"
        echo "  $0 authentik"
        echo "  $0 restore authentik_20240215_120000.sql.gz authentik-postgresql"
        exit 1
        ;;
esac
