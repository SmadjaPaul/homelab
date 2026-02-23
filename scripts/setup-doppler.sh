#!/bin/bash
# Setup Doppler projects for Homelab (Multi-Project)
# ===================================================
# Creates multiple Doppler projects following MacroPower's pattern

set -e

echo "=================================="
echo "Doppler Multi-Project Setup"
echo "=================================="
echo ""

# Check Doppler CLI
if ! command -v doppler &> /dev/null; then
    echo "Installing Doppler CLI..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install dopplerhq/cli/doppler
    else
        (curl -Ls --tlsv1.2 --proto "=https" --retry 3 https://cli.doppler.com/install.sh || \
         wget -t 3 -qO- https://cli.doppler.com/install.sh) | sh
    fi
fi

# Login
if ! doppler me &> /dev/null; then
    echo "Please login to Doppler:"
    doppler login
fi

echo "✅ Connected to Doppler"
echo ""

# Define projects with descriptions
declare -A PROJECTS=(
    ["infra-core"]="Core infrastructure (Traefik, Cert-manager)"
    ["cloudflare"]="Cloudflare services (Tunnel, DNS)"
    ["omni"]="Talos management (Omni)"
    ["homepage"]="Dashboard (Homepage)"
    ["n8n"]="Workflow automation (n8n)"
    ["adguard"]="DNS filtering (AdGuard)"
    ["opencloud"]="File storage (OpenCloud)"
    ["grafana"]="Observability (Grafana, Loki, Tempo)"
    ["robusta"]="Monitoring & alerting (Robusta)"
)

echo "Creating Doppler projects..."
echo ""

for project in "${!PROJECTS[@]}"; do
    desc="${PROJECTS[$project]}"

    if doppler projects get "$project" &> /dev/null; then
        echo "  ✅ $project already exists"
    else
        echo "  📝 Creating $project..."
        doppler projects create "$project" --description "$desc"

        # Create prod config
        doppler configs create prod -p "$project" 2>/dev/null || true
        echo "     Created config: prod"
    fi
done

echo ""
echo "=================================="
echo "Setup Complete!"
echo "=================================="
echo ""
echo "Created projects:"
for project in "${!PROJECTS[@]}"; do
    echo "  - $project: ${PROJECTS[$project]}"
done
echo ""
echo "Next steps:"
echo ""
echo "1. Generate auto-secrets with Terraform:"
echo "   cd terraform/secrets"
echo "   export DOPPLER_TOKEN=dp.st.xxxxx  # Your personal token"
echo "   terraform init && terraform apply"
echo ""
echo "2. Add manual secrets:"
echo "   doppler secrets set TUNNEL_TOKEN='<cf-token>' -p cloudflare -c prod"
echo "   doppler secrets set account_id='<id>' -p robusta -c prod"
echo "   doppler secrets set signing_key='<key>' -p robusta -c prod"
echo ""
echo "3. Generate service tokens:"
echo "   ./scripts/generate-doppler-tokens.sh"
echo ""
echo "4. Apply to Kubernetes:"
echo "   bash /tmp/doppler-tokens-*/create-secrets.sh"
echo "   kubectl apply -f kubernetes/bootstrap/doppler/secret-stores.yaml"
echo ""
echo "5. Deploy:"
echo "   ./kubernetes/bootstrap/deploy.sh oci  # or 'home'"
echo ""
