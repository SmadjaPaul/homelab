#!/bin/bash
# =============================================================================
# Initialize Doppler Secrets for Homelab
# =============================================================================
# This script helps you set up all required secrets in Doppler
# Run this once to initialize your Doppler project

set -e

PROJECT="infrastructure"
CONFIG="prd"

echo "🔐 Doppler Secret Initializer"
echo "=============================="
echo ""

# Check if doppler CLI is installed
if ! command -v doppler &> /dev/null; then
    echo "❌ Doppler CLI not found. Install it with: brew install doppler"
    exit 1
fi

# Check if logged in
if ! doppler whoami &> /dev/null; then
    echo "❌ Not logged in to Doppler. Run: doppler login"
    exit 1
fi

echo "Project: $PROJECT"
echo "Config: $CONFIG"
echo ""

# Function to set a secret if not already set
set_secret() {
    local key=$1
    local description=$2
    local current_value=$(doppler secrets get $key -p $PROJECT -c $CONFIG --plain 2>/dev/null || echo "")

    if [ -z "$current_value" ]; then
        echo "⚠️  $key is not set"
        echo "   Description: $description"
        read -p "   Enter value (or press Enter to skip): " value
        if [ -n "$value" ]; then
            doppler secrets set $key="$value" -p $PROJECT -c $CONFIG
            echo "   ✅ Set $key"
        else
            echo "   ⏭️  Skipped $key"
        fi
    else
        echo "✅ $key is already set"
    fi
}

# Function to generate a random secret
generate_secret() {
    local key=$1
    local description=$2
    local current_value=$(doppler secrets get $key -p $PROJECT -c $CONFIG --plain 2>/dev/null || echo "")

    if [ -z "$current_value" ]; then
        echo "⚠️  $key is not set"
        echo "   Description: $description"
        read -p "   Generate random value? (y/n): " generate
        if [ "$generate" = "y" ]; then
            local value=$(openssl rand -base64 60)
            doppler secrets set $key="$value" -p $PROJECT -c $CONFIG
            echo "   ✅ Generated and set $key"
        else
            read -p "   Enter value (or press Enter to skip): " value
            if [ -n "$value" ]; then
                doppler secrets set $key="$value" -p $PROJECT -c $CONFIG
                echo "   ✅ Set $key"
            else
                echo "   ⏭️  Skipped $key"
            fi
        fi
    else
        echo "✅ $key is already set"
    fi
}

echo "📋 Core Infrastructure Secrets"
echo "------------------------------"
set_secret "DOMAIN" "Root domain (e.g., smadja.dev)"
set_secret "CLOUDFLARE_ZONE_ID" "Cloudflare Zone ID"
set_secret "CLOUDFLARE_API_TOKEN" "Cloudflare API token"
set_secret "CLOUDFLARE_ACCOUNT_ID" "Cloudflare Account ID"
set_secret "CLOUDFLARE_TUNNEL_ID" "Cloudflare Tunnel ID"
set_secret "CLOUDFLARE_TUNNEL_SECRET" "Cloudflare Tunnel secret (base64)"
set_secret "CLOUDFLARE_TUNNEL_TOKEN" "Cloudflare Tunnel token"

echo ""
echo "📋 OCI Secrets"
echo "--------------"
set_secret "OCI_CLI_USER" "OCI User OCID"
set_secret "OCI_CLI_FINGERPRINT" "OCI API Key Fingerprint"
set_secret "OCI_CLI_TENANCY" "OCI Tenancy OCID"
set_secret "OCI_CLI_REGION" "OCI Region (e.g., eu-paris-1)"
set_secret "OCI_CLI_KEY_CONTENT" "OCI API Private Key"
set_secret "OCI_COMPARTMENT_ID" "OCI Compartment OCID"

echo ""
echo "📋 SSH Keys"
echo "-----------"
set_secret "SSH_PUBLIC_KEY" "SSH public key for VMs"

# Check for SSH private key
SSH_PRIVATE_KEY=$(doppler secrets get SSH_PRIVATE_KEY -p $PROJECT -c $CONFIG --plain 2>/dev/null || echo "")
if [ -z "$SSH_PRIVATE_KEY" ]; then
    echo "⚠️  SSH_PRIVATE_KEY is not set"
    read -p "   Load from file? (path or Enter to skip): " ssh_path
    if [ -n "$ssh_path" ] && [ -f "$ssh_path" ]; then
        doppler secrets set SSH_PRIVATE_KEY="$(cat $ssh_path)" -p $PROJECT -c $CONFIG
        echo "   ✅ Set SSH_PRIVATE_KEY from $ssh_path"
    fi
fi

echo ""
echo "📋 Authentik Secrets"
echo "--------------------"
set_secret "AUTHENTIK_URL" "Authentik URL (e.g., https://auth.smadja.dev)"
generate_secret "AUTHENTIK_SECRET_KEY" "Authentik secret key"
set_secret "AUTHENTIK_BOOTSTRAP_PASSWORD" "Initial admin password"
set_secret "AUTHENTIK_POSTGRESQL__PASSWORD" "PostgreSQL password for Authentik"

echo ""
echo "📋 Flux GitOps Secrets"
echo "----------------------"
# Check for Flux SSH key
FLUX_SSH_KEY=$(doppler secrets get FLUX_GIT_SSH_KEY -p $PROJECT -c $CONFIG --plain 2>/dev/null || echo "")
if [ -z "$FLUX_SSH_KEY" ]; then
    echo "⚠️  FLUX_GIT_SSH_KEY is not set"
    echo "   This is the SSH private key for Flux to access your Git repository"
    read -p "   Load from file? (path or Enter to generate new key): " flux_key_path
    if [ -n "$flux_key_path" ] && [ -f "$flux_key_path" ]; then
        doppler secrets set FLUX_GIT_SSH_KEY="$(cat $flux_key_path)" -p $PROJECT -c $CONFIG
        echo "   ✅ Set FLUX_GIT_SSH_KEY from $flux_key_path"
    else
        echo "   Generating new SSH key..."
        mkdir -p /tmp/flux-ssh
        ssh-keygen -t ed25519 -f /tmp/flux-ssh/identity -N "" -C "flux@homelab"
        doppler secrets set FLUX_GIT_SSH_KEY="$(cat /tmp/flux-ssh/identity)" -p $PROJECT -c $CONFIG
        echo "   ✅ Generated and set FLUX_GIT_SSH_KEY"
        echo ""
        echo "   📋 Add this public key as a Deploy Key in your GitHub repository:"
        echo "   Settings → Deploy keys → Add new"
        echo ""
        cat /tmp/flux-ssh/identity.pub
        echo ""
        rm -rf /tmp/flux-ssh
    fi
else
    echo "✅ FLUX_GIT_SSH_KEY is already set"
fi

echo ""
echo "📋 Tailscale Secrets (Optional)"
echo "-------------------------------"
set_secret "TS_OAUTH_CLIENT_ID" "Tailscale OAuth Client ID"
set_secret "TS_OAUTH_SECRET" "Tailscale OAuth Secret"

echo ""
echo "=============================="
echo "✅ Secret initialization complete!"
echo ""
echo "Next steps:"
echo "1. Generate a Doppler Service Token: doppler configs tokens create prd infrastructure-prd-token -p $PROJECT --plain"
echo "2. Add the token to GitHub Secrets as DOPPLER_SERVICE_TOKEN"
echo "3. Run the deploy workflow"
