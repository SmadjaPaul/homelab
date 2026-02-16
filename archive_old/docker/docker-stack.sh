#!/bin/bash
# Docker Modular Stack Management Script
# Usage: ./docker-stack.sh [start|stop|restart|logs|backup] [service]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if Doppler CLI is installed
check_doppler() {
    if ! command -v doppler &> /dev/null; then
        log_error "Doppler CLI is not installed"
        log_info "Install with: brew install doppler (macOS) or curl -Ls https://cli.doppler.com/install.sh | sh (Linux)"
        exit 1
    fi

    if ! doppler configs &> /dev/null; then
        log_error "Not logged in to Doppler"
        log_info "Run: doppler login"
        exit 1
    fi
}

# Create external networks if they don't exist
setup_networks() {
    log_info "Setting up Docker networks..."

    docker network inspect traefik-public &> /dev/null || docker network create traefik-public
    docker network inspect authentik-private &> /dev/null || docker network create authentik-private
    docker network inspect monitoring &> /dev/null || docker network create monitoring
    docker network inspect streaming &> /dev/null || docker network create streaming

    log_success "Networks created"
}

# Start services
start_service() {
    local service=$1
    local project=$2

    log_info "Starting $service..."

    if [ ! -d "$COMPOSE_DIR/$service" ]; then
        log_error "Service directory not found: $COMPOSE_DIR/$service"
        exit 1
    fi

    cd "$COMPOSE_DIR/$service"

    if [ -f "docker-compose.yml" ]; then
        if [ -n "$project" ]; then
            doppler run -p "$project" -c prd -- docker-compose up -d
        else
            docker-compose up -d
        fi
        log_success "$service started"
    else
        log_error "docker-compose.yml not found in $service"
        exit 1
    fi
}

# Stop services
stop_service() {
    local service=$1

    log_info "Stopping $service..."

    if [ -d "$COMPOSE_DIR/$service" ]; then
        cd "$COMPOSE_DIR/$service"
        docker-compose down
        log_success "$service stopped"
    fi
}

# View logs
view_logs() {
    local service=$1
    local follow=$2

    cd "$COMPOSE_DIR/$service"

    if [ "$follow" = "true" ]; then
        docker-compose logs -f
    else
        docker-compose logs --tail 100
    fi
}

# Main command handler
case "${1:-}" in
    start)
        check_doppler
        setup_networks

        case "${2:-all}" in
            all)
                log_info "Starting all services..."
                start_service "core" "infrastructure"
                sleep 5
                start_service "authentik" "infrastructure"
                sleep 10
                start_service "monitoring" "infrastructure"
                start_service "services/comet" "infrastructure"
                log_success "All services started"
                ;;
            core)
                start_service "core" "infrastructure"
                ;;
            authentik)
                start_service "authentik" "infrastructure"
                ;;
            monitoring)
                start_service "monitoring" "infrastructure"
                ;;
            comet)
                start_service "services/comet" "infrastructure"
                ;;
            *)
                log_error "Unknown service: $2"
                echo "Available: all, core, authentik, monitoring, comet"
                exit 1
                ;;
        esac
        ;;

    stop)
        case "${2:-all}" in
            all)
                log_info "Stopping all services..."
                stop_service "services/comet"
                stop_service "monitoring"
                stop_service "authentik"
                stop_service "core"
                log_success "All services stopped"
                ;;
            *)
                stop_service "$2"
                ;;
        esac
        ;;

    restart)
        $0 stop "$2"
        sleep 2
        $0 start "$2"
        ;;

    logs)
        view_logs "${2:-core}" "${3:-false}"
        ;;

    backup)
        "$SCRIPT_DIR/backup.sh"
        ;;

    *)
        echo "Usage: $0 {start|stop|restart|logs|backup} [service]"
        echo ""
        echo "Services:"
        echo "  all         - All services"
        echo "  core        - Traefik + Cloudflared"
        echo "  authentik   - Authentik + PostgreSQL + Redis"
        echo "  monitoring  - Prometheus + Grafana Alloy"
        echo "  comet       - Comet streaming service"
        echo ""
        echo "Examples:"
        echo "  $0 start all"
        echo "  $0 restart authentik"
        echo "  $0 logs authentik -f"
        echo "  $0 backup"
        exit 1
        ;;
esac
