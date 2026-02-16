#!/bin/bash
#
# Setup Doppler projects for Homelab
# Creates 1 project per service for granular secret management
#

set -e

echo "🔐 Doppler Project Setup"
echo "======================="
echo ""

# Check Doppler CLI
if ! command -v doppler &> /dev/null; then
    echo "❌ Doppler CLI not found"
    echo "Install: curl -sLf https://cli.doppler.com/install.sh | sh"
    exit 1
fi

# Check login
doppler me &> /dev/null || {
    echo "❌ Not logged in. Run: doppler login"
    exit 1
}

echo "✅ Connected to Doppler"
echo ""

# Define projects
PROJECTS=(
    "infrastructure:Infrastructure core secrets"
    "service-authentik:Identity Provider"
    "service-nextcloud:Cloud storage"
    "service-comet:Stremio streaming"
    "service-jellyfin:Media server"
    "service-odoo:ERP Business"
    "service-fleetdm:Device Management"
    "service-matrix:Messaging"
    "service-immich:Photo management"
    "service-vaultwarden:Password manager"
    "service-gitea:Git hosting"
    "service-litellm:AI Gateway"
    "service-openwebui:AI Chat interface"
    "backup-kopia:Backup tool"
)

echo "Creating projects..."
for project_info in "${PROJECTS[@]}"; do
    IFS=':' read -r project_name description <<< "$project_info"

    if doppler projects get "$project_name" &> /dev/null; then
        echo "  ✅ $project_name already exists"
    else
        echo "  📝 Creating $project_name ($description)..."
        doppler projects create "$project_name" --description "$description"

        # Create production config
        doppler configs create prd -p "$project_name" || true

        echo "     Created config: prd"
    fi
done

echo ""
echo "Generating service tokens..."
echo ""

# Create tokens file
TOKENS_FILE="/tmp/doppler_tokens.txt"
echo "# Doppler Service Tokens" > "$TOKENS_FILE"
echo "# Generated: $(date)" >> "$TOKENS_FILE"
echo "" >> "$TOKENS_FILE"

for project_info in "${PROJECTS[@]}"; do
    IFS=':' read -r project_name _ <<< "$project_info"

    echo "Project: $project_name"

    # Skip infrastructure (we'll do it separately)
    if [ "$project_name" == "infrastructure" ]; then
        token=$(doppler configs tokens create prd "eso-token-$(date +%Y%m%d)" -p "$project_name" --plain)
        echo "  Infrastructure Token: $token"
        echo "INFRASTRUCTURE_TOKEN=$token" >> "$TOKENS_FILE"
        continue
    fi

    # Generate token
    token=$(doppler configs tokens create prd "eso-token-$(date +%Y%m%d)" -p "$project_name" --plain)

    # Convert project name to env var name
    env_var_name="DOPPLER_TOKEN_$(echo "$project_name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"

    echo "  Token: $token"
    echo "$env_var_name=$token" >> "$TOKENS_FILE"

    # Add to infrastructure project
    echo "  → Adding to infrastructure project..."
    doppler secrets set "$env_var_name"="$token" -p infrastructure --silent || true
done

echo ""
echo "✅ Setup complete!"
echo ""
echo "Tokens saved to: $TOKENS_FILE"
echo ""
echo "Next steps:"
echo "  1. Add your secrets to each Doppler project"
echo "     See doppler.yaml for the list of required secrets"
echo ""
echo "  2. For local development, run:"
echo "     doppler configure --project infrastructure --config prd"
echo ""
echo "  3. To inject secrets into Terraform:"
echo "     export DOPPLER_TOKEN=$(doppler configs tokens create prd temp -p infrastructure --plain)"
echo "     doppler run -- terraform plan"
echo ""
echo "  4. Bootstrap the cluster:"
echo "     ./scripts/bootstrap.sh"
