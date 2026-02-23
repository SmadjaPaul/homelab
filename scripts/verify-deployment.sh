#!/bin/bash
# Post-Deployment Verification Script
# ====================================
# Verifies that all components are correctly deployed

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

echo "=================================="
echo "Post-Deployment Verification"
echo "=================================="
echo ""

# Check kubectl connection
echo "Checking kubectl connection..."
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Kubernetes cluster accessible${NC}"
echo ""

# Check Doppler secrets
echo "Checking Doppler secrets..."
REQUIRED_SECRETS=("infra-core" "cloudflare" "robusta" "grafana" "n8n" "opencloud")
for secret in "${REQUIRED_SECRETS[@]}"; do
    if kubectl get secret "doppler-token-${secret}" -n kube > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Secret doppler-token-${secret}${NC}"
    else
        echo -e "${RED}❌ Missing secret: doppler-token-${secret}${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# Check ClusterSecretStores
echo "Checking ClusterSecretStores..."
STORES=$(kubectl get clustersecretstore -o name 2>/dev/null | wc -l)
if [ "$STORES" -ge 5 ]; then
    echo -e "${GREEN}✅ Found $STORES ClusterSecretStores${NC}"
else
    echo -e "${RED}❌ Only $STORES ClusterSecretStores found (expected 10)${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check External Secrets
echo "Checking External Secrets..."
NOT_READY=$(kubectl get externalsecret -A --no-headers 2>/dev/null | grep -v "True" | wc -l)
if [ "$NOT_READY" -eq 0 ]; then
    echo -e "${GREEN}✅ All External Secrets are ready${NC}"
else
    echo -e "${YELLOW}⚠️  $NOT_READY External Secrets not ready${NC}"
    kubectl get externalsecret -A | grep -v "True" | head -10
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Check Flux CD
echo "Checking Flux CD..."
if kubectl get ns flux-system > /dev/null 2>&1; then
    echo -e "${GREEN}✅ flux-system namespace found${NC}"
else
    echo -e "${RED}❌ flux-system namespace not found${NC}"
    ERRORS=$((ERRORS + 1))
fi

FLUX_KUSTOMIZATIONS=$(kubectl get kustomizations -A --no-headers 2>/dev/null | wc -l)
if [ "$FLUX_KUSTOMIZATIONS" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $FLUX_KUSTOMIZATIONS Flux kustomizations${NC}"

    # Check for non-ready kustomizations
    NOT_READY_K=$(kubectl get kustomizations -A --no-headers 2>/dev/null | grep -v "True" | wc -l)
    if [ "$NOT_READY_K" -eq 0 ]; then
        echo -e "${GREEN}✅ All kustomizations ready${NC}"
    else
        echo -e "${YELLOW}⚠️  $NOT_READY_K kustomizations not ready${NC}"
        kubectl get kustomizations -A | grep -v "True"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${RED}❌ No Flux kustomizations found${NC}"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Check critical services
echo "Checking critical services..."
SERVICES=(
    "traefik:kube"
    "cert-manager:kube"
    "external-secrets:kube"
    "cloudflared:cloudflared"
    "robusta:robusta"
)

for svc_info in "${SERVICES[@]}"; do
    IFS=':' read -r svc namespace <<< "$svc_info"
    if kubectl get pods -n "$namespace" -l app.kubernetes.io/name="$svc" 2>/dev/null | grep -q Running; then
        echo -e "${GREEN}✅ $svc running${NC}"
    else
        echo -e "${YELLOW}⚠️  $svc may not be running${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
done
echo ""

# Check nodes
echo "Checking cluster nodes..."
NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
echo -e "${GREEN}✅ Found $NODES nodes${NC}"
kubectl get nodes
echo ""

# Summary
echo "=================================="
echo "Verification Summary"
echo "=================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Check Flux logs: flux logs --all-namespaces"
    echo "2. Check Flux alerts: flux get alerts"
    echo "3. Configure Auth0: https://manage.auth0.com"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS warnings (non-critical)${NC}"
    echo ""
    echo "Some components may still be starting up."
    echo "Run this script again in 2-3 minutes."
    exit 0
else
    echo -e "${RED}❌ $ERRORS errors found${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $WARNINGS warnings${NC}"
    fi
    echo ""
    echo "Please fix the errors above before continuing."
    exit 1
fi
