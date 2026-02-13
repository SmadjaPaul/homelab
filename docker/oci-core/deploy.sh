#!/bin/bash
# OCI Core Deployment Script
# Deploys maximum uptime services to Oracle Cloud

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker not found. Please install Docker first."
        exit 1
    fi
    
    # Check Doppler
    if ! command -v doppler &> /dev/null; then
        print_error "Doppler CLI not found. Installing..."
        curl -Ls https://cli.doppler.com/install.sh | sudo sh
    fi
    
    # Check Doppler login
    if ! doppler me &> /dev/null; then
        print_error "Please login to Doppler first:"
        echo "  doppler login"
        exit 1
    fi
    
    print_success "Prerequisites OK"
}

# Create required directories
create_directories() {
    print_status "Creating data directories..."
    
    mkdir -p data/traefik/letsencrypt
    mkdir -p data/authentik/{postgres,redis,media,custom-templates,certs}
    mkdir -p data/prometheus
    mkdir -p data/uptime-kuma
    mkdir -p data/gotify
    mkdir -p data/gitea
    mkdir -p data/vaultwarden
    mkdir -p data/filebrowser/database
    mkdir -p config
    
    print_success "Directories created"
}

# Check secrets
check_secrets() {
    print_status "Checking Doppler secrets..."
    
    required_secrets=(
        "CLOUDFLARE_TUNNEL_TOKEN"
        "ACME_EMAIL"
    )
    
    missing_secrets=()
    
    for secret in "${required_secrets[@]}"; do
        if ! doppler secrets -p infrastructure get "$secret" &> /dev/null; then
            missing_secrets+=("$secret")
        fi
    done
    
    if [ ${#missing_secrets[@]} -ne 0 ]; then
        print_error "Missing required secrets in Doppler (infrastructure project):"
        for secret in "${missing_secrets[@]}"; do
            echo "  - $secret"
        done
        echo ""
        echo "Add them with:"
        echo "  doppler secrets set SECRET_NAME=value -p infrastructure"
        exit 1
    fi
    
    print_success "Required secrets OK"
}

# Deploy services
deploy() {
    local profile=$1
    
    print_status "Deploying profile: $profile"
    
    doppler run --project infrastructure --config prd -- \
        docker compose --profile "$profile" up -d
    
    print_success "Profile $profile deployed"
}

# Check service health
check_health() {
    print_status "Checking service health..."
    
    sleep 5
    
    # Get running containers
    running=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep -c "Up" || true)
    
    if [ "$running" -eq 0 ]; then
        print_error "No containers running!"
        docker compose ps
        exit 1
    fi
    
    print_success "$running containers running"
    
    # Show status
    echo ""
    docker compose ps
}

# Show URLs
show_urls() {
    echo ""
    echo "=========================================="
    echo "  Services deployed successfully!"
    echo "=========================================="
    echo ""
    echo "URLs:"
    echo "  Homepage:     https://smadja.dev"
    echo "  DNS:          https://dns.smadja.dev"
    echo "  Auth:         https://auth.smadja.dev"
    echo "  Git:          https://git.smadja.dev"
    echo "  Vault:        https://vault.smadja.dev"
    echo "  Files:        https://files.smadja.dev"
    echo "  Status:       https://status.smadja.dev"
    echo "  Notify:       https://notify.smadja.dev"
    echo ""
    echo "Grafana Cloud: https://grafana.com"
    echo ""
}

# Main menu
show_menu() {
    echo ""
    echo "OCI Core Deployment"
    echo "==================="
    echo ""
    echo "Available profiles:"
    echo "  1) core       - Essential services (Traefik, Tunnel, Blocky)"
    echo "  2) monitoring - Prometheus, Uptime Kuma, Gotify, Grafana Agent"
    echo "  3) apps       - Homepage, Gitea, Vaultwarden, File Browser"
    echo "  4) authentik  - Authentication/SSO (resource heavy)"
    echo "  5) vpn        - Twingate VPN"
    echo "  6) all        - Everything (requires 6GB+ RAM)"
    echo ""
    echo "Commands:"
    echo "  ./deploy.sh [profile]"
    echo "  ./deploy.sh core"
    echo "  ./deploy.sh all"
    echo "  ./deploy.sh down"
    echo "  ./deploy.sh logs [service]"
    echo "  ./deploy.sh update"
    echo ""
}

# Main
main() {
    local command=${1:-menu}
    
    case "$command" in
        menu)
            show_menu
            ;;
        core|monitoring|apps|authentik|vpn|all)
            check_prerequisites
            create_directories
            check_secrets
            deploy "$command"
            check_health
            show_urls
            ;;
        down)
            print_status "Stopping all services..."
            docker compose --profile all down
            print_success "Services stopped"
            ;;
        logs)
            service=${2:-}
            if [ -z "$service" ]; then
                docker compose logs -f
            else
                docker logs -f "$service"
            fi
            ;;
        update)
            print_status "Updating services..."
            doppler run --project infrastructure --config prd -- \
                docker compose --profile all pull
            doppler run --project infrastructure --config prd -- \
                docker compose --profile all up -d
            print_success "Services updated"
            ;;
        status)
            docker compose ps
            ;;
        *)
            print_error "Unknown command: $command"
            show_menu
            exit 1
            ;;
    esac
}

# Run main
main "$@"
