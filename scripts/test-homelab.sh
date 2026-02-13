#!/bin/bash
# Test script for homelab services
# Usage: ./test-homelab.sh [domain]

DOMAIN=${1:-smadja.dev}
TIMEOUT=10

echo "🧪 Testing Homelab Services"
echo "============================"
echo "Domain: $DOMAIN"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to test URL
test_url() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}

    echo -n "Testing $name ($url)... "

    # Follow redirects, timeout after 10s
    response=$(curl -sL -o /dev/null -w "%{http_code}|%{time_total}" --max-time $TIMEOUT "$url" 2>&1)
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}❌ FAIL${NC} (Connection error: $exit_code)"
        return 1
    fi

    http_code=$(echo "$response" | cut -d'|' -f1)
    response_time=$(echo "$response" | cut -d'|' -f2)

    if [ "$http_code" = "$expected_code" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
        echo -e "${GREEN}✅ OK${NC} (HTTP $http_code, ${response_time}s)"
        return 0
    else
        echo -e "${YELLOW}⚠️  WARN${NC} (HTTP $http_code, expected $expected_code)"
        return 1
    fi
}

# Test external URLs
echo "📡 Testing External URLs (via Cloudflare Tunnel):"
echo "---------------------------------------------------"

test_url "Root Domain" "https://$DOMAIN"
test_url "Traefik Dashboard" "https://traefik.$DOMAIN"
test_url "Prometheus" "https://prometheus.$DOMAIN"
test_url "Blocky DNS" "https://dns.$DOMAIN" "404"  # Blocky might return 404 on root
test_url "Grafana" "https://grafana.$DOMAIN" "302"  # Redirect to auth

echo ""
echo "🔒 Testing Access-Protected Services (should redirect to auth):"
echo "---------------------------------------------------------------"

test_url "LLM (LiteLLM)" "https://llm.$DOMAIN" "302"
test_url "OpenClaw" "https://openclaw.$DOMAIN" "302"

echo ""
echo "🌐 Testing DNS Resolution:"
echo "--------------------------"

# Test DNS
echo -n "DNS resolution for $DOMAIN... "
if host "$DOMAIN" > /dev/null 2>&1; then
    ip=$(host "$DOMAIN" | head -1 | awk '{print $4}')
    echo -e "${GREEN}✅ OK${NC} ($ip)"
else
    echo -e "${RED}❌ FAIL${NC} (Cannot resolve)"
fi

echo ""
echo "🐳 Testing Docker Services (via SSH):"
echo "--------------------------------------"

# Check if we can SSH and verify containers
if ssh -i ~/.ssh/oci-homelab -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@158.178.210.98 "docker ps" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ SSH Connection OK${NC}"

    # Get container status
    echo ""
    echo "Container Status:"
    ssh -i ~/.ssh/oci-homelab -o StrictHostKeyChecking=no ubuntu@158.178.210.98 "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" 2>/dev/null || echo -e "${RED}❌ Failed to get container status${NC}"

    # Check for restarting containers
    restarting=$(ssh -i ~/.ssh/oci-homelab -o StrictHostKeyChecking=no ubuntu@158.178.210.98 "docker ps --filter 'status=restarting' --format '{{.Names}}'" 2>/dev/null)
    if [ -n "$restarting" ]; then
        echo ""
        echo -e "${YELLOW}⚠️  WARNING: The following containers are restarting:${NC}"
        echo "$restarting"
    fi
else
    echo -e "${RED}❌ SSH Connection FAILED${NC}"
fi

echo ""
echo "📊 Summary:"
echo "-----------"
echo "If all external URLs return ✅, your homelab is accessible via Cloudflare Tunnel."
echo "If you see ⚠️  or ❌, check the following:"
echo "  1. Cloudflare Tunnel is connected (cloudflared container)"
echo "  2. Traefik is running and configured"
echo "  3. DNS records point to the tunnel"
echo "  4. Services are healthy (docker ps)"
echo ""
echo "🔗 Useful Commands:"
echo "  - Check containers: ssh oci-mgmt 'docker ps'"
echo "  - Check logs: ssh oci-mgmt 'docker logs cloudflared --tail 20'"
echo "  - Restart services: ssh oci-mgmt 'cd /opt/oci-core && docker compose restart'"
