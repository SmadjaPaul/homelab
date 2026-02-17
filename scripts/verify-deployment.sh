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
REQUIRED_SECRETS=("infra-core" "cloudflare" "authentik" "robusta" "grafana" "n8n" "opencloud")
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

# Check Argo CD
echo "Checking Argo CD..."
if kubectl get pods -n argo-cd -l app.kubernetes.io/name=argocd-server > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Argo CD pods found${NC}"
else
    echo -e "${RED}❌ Argo CD not found${NC}"
    ERRORS=$((ERRORS + 1))
fi

ARGO_APPS=$(kubectl get applications -n argo-cd --no-headers 2>/dev/null | wc -l)
if [ "$ARGO_APPS" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $ARGO_APPS Argo CD applications${NC}"

    # Check for non-synced apps
    NOT_SYNCED=$(kubectl get applications -n argo-cd --no-headers 2>/dev/null | grep -v "Synced" | wc -l)
    if [ "$NOT_SYNCED" -eq 0 ]; then
        echo -e "${GREEN}✅ All applications synced${NC}"
    else
        echo -e "${YELLOW}⚠️  $NOT_SYNCED applications not synced${NC}"
        kubectl get applications -n argo-cd | grep -v "Synced"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${RED}❌ No Argo CD applications found${NC}"
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
    echo "1. Access Argo CD: kubectl port-forward svc/argocd-server -n argo-cd 8080:443"
    echo "2. Get password: kubectl -n argo-cd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    echo "3. Configure Authentik: https://authentik.k8s.smadja.dev"
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
