#!/bin/bash
# Generate Doppler Service Tokens for Kubernetes (Multi-Project)
# ===============================================================
# Creates service tokens in all Doppler projects for Kubernetes

set -e

echo "=================================="
echo "Doppler Multi-Project Token Generator"
echo "=================================="
echo ""

# Check Doppler CLI
if ! command -v doppler &> /dev/null; then
    echo "❌ Doppler CLI not found"
    echo "Install: curl -sLf https://cli.doppler.com/install.sh | sh"
    exit 1
fi

if ! doppler me &> /dev/null; then
    echo "❌ Not logged in. Run: doppler login"
    exit 1
fi

# Define all projects
PROJECTS=(
    "infra-core"
    "cloudflare"
    "authentik"
    "omni"
    "homepage"
    "n8n"
    "adguard"
    "opencloud"
    "grafana"
    "robusta"
)

echo "Projects to process:"
for project in "${PROJECTS[@]}"; do
    echo "  - $project"
done
echo ""

read -p "Continue? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

# Create output directory
OUTPUT_DIR="/tmp/doppler-tokens-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR"

# File for kubectl commands
KUBECTL_FILE="$OUTPUT_DIR/create-secrets.sh"
echo "#!/bin/bash" > "$KUBECTL_FILE"
echo "# Create Doppler token secrets in Kubernetes" >> "$KUBECTL_FILE"
echo "# Generated: $(date)" >> "$KUBECTL_FILE"
echo "" >> "$KUBECTL_FILE"
echo "set -e" >> "$KUBECTL_FILE"
echo "" >> "$KUBECTL_FILE"

# File for reference
TOKENS_FILE="$OUTPUT_DIR/tokens.txt"
echo "# Doppler Service Tokens" > "$TOKENS_FILE"
echo "# Generated: $(date)" >> "$TOKENS_FILE"
echo "# KEEP THIS FILE SECURE!" >> "$TOKENS_FILE"
echo "" >> "$TOKENS_FILE"

echo ""
echo "Creating tokens..."
echo ""

for project in "${PROJECTS[@]}"; do
    echo "Processing: $project"

    # Check if project exists
    if ! doppler projects get "$project" &> /dev/null; then
        echo "  ⚠️  Project '$project' not found. Skipping..."
        continue
    fi

    # Check if prod config exists
    if ! doppler configs get prod -p "$project" &> /dev/null; then
        echo "  📝 Creating prod config for $project..."
        doppler configs create prod -p "$project" 2>/dev/null || true
    fi

    # Create token
    token_name="k8s-$(date +%Y%m%d)"
    token=$(doppler configs tokens create prod "$token_name" -p "$project" --plain 2>/dev/null || echo "ERROR")

    if [ "$token" == "ERROR" ] || [ -z "$token" ]; then
        echo "  ❌ Failed to create token"
        continue
    fi

    echo "  ✅ Token created"

    # Save token
    echo "$project=$token" >> "$TOKENS_FILE"

    # Generate kubectl command
    secret_name="doppler-token-${project}"
    cat >> "$KUBECTL_FILE" <<EOF
# $project
echo "Creating secret for $project..."
kubectl create secret generic $secret_name \
  --from-literal=dopplerToken='$token' \
  -n kube --dry-run=client -o yaml | kubectl apply -f -

EOF

    sleep 0.5  # Rate limiting
done

echo ""
echo "=================================="
echo "Token Generation Complete!"
echo "=================================="
echo ""
echo "Files created:"
echo "  Tokens:     $TOKENS_FILE"
echo "  K8s Script: $KUBECTL_FILE"
echo ""
echo "Next steps:"
echo ""
echo "1. Review the generated script:"
echo "   cat $KUBECTL_FILE"
echo ""
echo "2. Apply to Kubernetes:"
echo "   bash $KUBECTL_FILE"
echo ""
echo "3. Verify secrets created:"
echo "   kubectl get secrets -n kube | grep doppler-token"
echo ""
echo "4. Apply SecretStores:"
echo "   kubectl apply -f kubernetes/bootstrap/doppler/secret-stores.yaml"
echo ""
echo "5. Verify SecretStores:"
echo "   kubectl get clustersecretstore"
echo ""
echo "⚠️  IMPORTANT: Keep $TOKENS_FILE secure! It contains sensitive tokens."
echo "   Delete it after verifying everything works."
echo ""
