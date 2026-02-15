#!/bin/bash
# Final Deployment Script - Complete Homelab Setup
# Usage: ./deploy-final.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  HOMELAB FINAL DEPLOYMENT${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}${BOLD}$1${NC}"
    echo -e "${BLUE}$(printf '=%.0s' $(seq 1 ${#1}))${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_section "Checking Prerequisites"

    local missing=()

    if ! command_exists terraform; then
        missing+=("terraform")
    fi

    if ! command_exists doppler; then
        missing+=("doppler")
    fi

    if ! command_exists docker; then
        missing+=("docker")
    fi

    if ! command_exists docker-compose; then
        missing+=("docker-compose")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}❌ Missing required tools:${NC}"
        printf '  - %s\n' "${missing[@]}"
        echo ""
        echo "Install them and try again."
        exit 1
    fi

    echo -e "${GREEN}✅ All prerequisites met${NC}"

    # Check Doppler login
    if ! doppler me &>/dev/null; then
        echo -e "${RED}❌ Not logged in to Doppler${NC}"
        echo "Run: doppler login"
        exit 1
    fi

    echo -e "${GREEN}✅ Doppler authenticated${NC}"

    # Check Doppler project exists
    if ! doppler projects | grep -q "infrastructure"; then
        echo -e "${YELLOW}⚠️  Doppler project 'infrastructure' not found${NC}"
        echo "Create it with: doppler projects create infrastructure"
        exit 1
    fi

    echo -e "${GREEN}✅ Doppler project 'infrastructure' exists${NC}"
}

# Function to deploy Terraform
deploy_terraform() {
    print_section "Phase 1: Terraform (Cloudflare DNS & Rules)"

    cd "$SCRIPT_DIR/terraform/cloudflare"

    echo -e "${YELLOW}⏳ Initializing Terraform...${NC}"
    terraform init

    echo -e "${YELLOW}⏳ Planning changes...${NC}"
    terraform plan -out=tfplan

    echo ""
    read -r -p "Do you want to apply these Terraform changes? (y/N): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⏳ Applying Terraform...${NC}"
        terraform apply tfplan
        echo -e "${GREEN}✅ Terraform applied successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  Skipping Terraform apply${NC}"
    fi

    rm -f tfplan
}

# Function to create Docker networks
create_networks() {
    print_section "Phase 2: Creating Docker Networks"

    local networks=("traefik-public" "authentik-private" "monitoring" "streaming")

    for network in "${networks[@]}"; do
        if docker network inspect "$network" &>/dev/null; then
            echo -e "${GREEN}✅ Network '$network' already exists${NC}"
        else
            echo -e "${YELLOW}⏳ Creating network '$network'...${NC}"
            docker network create "$network"
            echo -e "${GREEN}✅ Network '$network' created${NC}"
        fi
    done
}

# Function to deploy services
deploy_services() {
    print_section "Phase 3: Deploying Docker Services"

    cd "$SCRIPT_DIR/docker"

    # Check if docker-stack.sh exists
    if [ ! -f "docker-stack.sh" ]; then
        echo -e "${RED}❌ docker-stack.sh not found${NC}"
        exit 1
    fi

    echo -e "${YELLOW}⏳ Deploying Core (Traefik + Cloudflared)...${NC}"
    doppler run -p infrastructure -c prd -- docker-compose -f core/docker-compose.yml up -d
    sleep 5

    echo -e "${YELLOW}⏳ Deploying Authentik...${NC}"
    doppler run -p infrastructure -c prd -- docker-compose -f authentik/docker-compose.yml up -d
    sleep 10

    echo -e "${YELLOW}⏳ Deploying Monitoring...${NC}"
    doppler run -p infrastructure -c prd -- docker-compose -f monitoring/docker-compose.yml up -d

    echo -e "${YELLOW}⏳ Deploying Comet (Streaming)...${NC}"
    doppler run -p infrastructure -c prd -- docker-compose -f services/comet/docker-compose.yml up -d

    echo -e "${GREEN}✅ All services deployed${NC}"
}

# Function to check health
check_health() {
    print_section "Phase 4: Health Check"

    echo -e "${YELLOW}⏳ Waiting 30 seconds for services to start...${NC}"
    sleep 30

    echo ""
    echo -e "${BLUE}Container Status:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    echo ""
    echo -e "${BLUE}Checking individual services...${NC}"

    # Check Traefik
    if curl -sf http://localhost:8080/ping &>/dev/null; then
        echo -e "${GREEN}✅ Traefik is responding${NC}"
    else
        echo -e "${YELLOW}⚠️  Traefik not responding on ping endpoint${NC}"
    fi

    # Check Authentik
    if curl -sf http://localhost:9000/-/health/ready/ &>/dev/null; then
        echo -e "${GREEN}✅ Authentik is ready${NC}"
    else
        echo -e "${YELLOW}⚠️  Authentik not ready yet${NC}"
    fi

    # Check Comet
    if curl -sf http://localhost:8000/manifest.json &>/dev/null; then
        echo -e "${GREEN}✅ Comet is responding${NC}"
    else
        echo -e "${YELLOW}⚠️  Comet not responding yet${NC}"
    fi

    echo ""
    echo -e "${BLUE}Unhealthy containers (if any):${NC}"
    docker ps --filter "health=unhealthy" --format "table {{.Names}}\t{{.Status}}"
}

# Function to verify DNS
verify_dns() {
    print_section "Phase 5: DNS Verification"

    echo -e "${YELLOW}⏳ Checking DNS propagation...${NC}"

    # Check stream.smadja.dev
    echo ""
    echo -e "${BLUE}stream.smadja.dev:${NC}"
    nslookup stream.smadja.dev || echo -e "${YELLOW}⚠️  DNS not yet propagated${NC}"

    # Check auth.smadja.dev
    echo ""
    echo -e "${BLUE}auth.smadja.dev:${NC}"
    nslookup auth.smadja.dev || echo -e "${YELLOW}⚠️  DNS not yet propagated${NC}"
}

# Function to show final status
show_summary() {
    print_section "Deployment Summary"

    echo ""
    echo -e "${GREEN}${BOLD}✅ Deployment Complete!${NC}"
    echo ""
    echo -e "${BOLD}Services:${NC}"
    echo "  • Authentik:      https://auth.smadja.dev"
    echo "  • Traefik:        https://traefik.smadja.dev"
    echo "  • Comet:          https://stream.smadja.dev"
    echo "  • Prometheus:     https://prometheus.smadja.dev"
    echo ""
    echo -e "${BOLD}Management:${NC}"
    echo "  • Start all:      ./docker/docker-stack.sh start all"
    echo "  • View logs:      ./docker/docker-stack.sh logs authentik -f"
    echo "  • Backup:         ./docker/scripts/backup.sh all"
    echo ""
    echo -e "${BOLD}Next Steps:${NC}"
    echo "  1. Access Authentik at https://auth.smadja.dev"
    echo "     Login: akadmin / [bootstrap password from Doppler]"
    echo "  2. Configure OAuth providers (optional)"
    echo "  3. Add Comet to Stremio: https://stream.smadja.dev/manifest.json"
    echo "  4. Review security analysis: docs/COMET_SECURITY_ANALYSIS.md"
    echo ""
    echo -e "${YELLOW}⚠️  Important:${NC}"
    echo "  • Change Authentik default password immediately!"
    echo "  • Review Real-Debrid TOS before sharing"
    echo "  • Monitor logs for first few days"
    echo ""
}

# Function to show help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Complete deployment script for Homelab infrastructure.

OPTIONS:
    --skip-terraform    Skip Terraform phase
    --skip-networks     Skip Docker network creation
    --skip-health       Skip health checks
    --help              Show this help message

EXAMPLES:
    $0                  # Full deployment
    $0 --skip-terraform # Deploy only Docker services

EOF
}

# Main function
main() {
    local skip_terraform=false
    local skip_networks=false
    local skip_health=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-terraform)
                skip_terraform=true
                shift
                ;;
            --skip-networks)
                skip_networks=true
                shift
                ;;
            --skip-health)
                skip_health=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Check prerequisites
    check_prerequisites

    # Deploy Terraform
    if [ "$skip_terraform" = false ]; then
        deploy_terraform
    else
        echo -e "${YELLOW}⚠️  Skipping Terraform${NC}"
    fi

    # Create Docker networks
    if [ "$skip_networks" = false ]; then
        create_networks
    else
        echo -e "${YELLOW}⚠️  Skipping network creation${NC}"
    fi

    # Deploy services
    deploy_services

    # Health check
    if [ "$skip_health" = false ]; then
        check_health
    else
        echo -e "${YELLOW}⚠️  Skipping health checks${NC}"
    fi

    # Verify DNS
    verify_dns

    # Show summary
    show_summary
}

# Run main function
main "$@"
