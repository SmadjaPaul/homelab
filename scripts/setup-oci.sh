#!/bin/bash
# Script to help set up Oracle Cloud CLI and GitHub secrets
# Usage: ./scripts/setup-oci.sh

set -e

echo "🚀 Oracle Cloud Setup Helper"
echo "============================"
echo ""

# Check if OCI CLI is installed
if ! command -v oci &> /dev/null; then
    echo "❌ OCI CLI not found. Install with: brew install oci-cli"
    exit 1
fi

# Check if already configured
if [ -f ~/.oci/config ]; then
    echo "✅ OCI CLI already configured"
    echo ""
    echo "Current configuration:"
    echo "---------------------"
    grep -E "^(user|tenancy|region|fingerprint)=" ~/.oci/config | head -4
    echo ""
    read -rp "Do you want to reconfigure? (y/N): " reconfigure
    if [ "$reconfigure" != "y" ] && [ "$reconfigure" != "Y" ]; then
        echo "Keeping existing configuration."
    else
        echo "Running oci setup config..."
        oci setup config
    fi
else
    echo "📝 Running OCI CLI setup..."
    echo ""
    echo "You'll need:"
    echo "1. User OCID    → Profile → Copy OCID"
    echo "2. Tenancy OCID → Administration → Tenancy Details → Copy OCID"
    echo "3. Region       → eu-paris-1 (or your region)"
    echo ""
    read -rp "Press Enter to continue..."
    oci setup config
fi

echo ""
echo "🔑 Generating SSH key for OCI instances..."
if [ -f ~/.ssh/oci-homelab ]; then
    echo "✅ SSH key already exists: ~/.ssh/oci-homelab"
else
    ssh-keygen -t ed25519 -f ~/.ssh/oci-homelab -N "" -C "homelab-oci"
    echo "✅ SSH key created: ~/.ssh/oci-homelab"
fi

echo ""
echo "📋 GitHub Secrets - Copy these values:"
echo "======================================="
echo ""

# Extract values from OCI config
if [ -f ~/.oci/config ]; then
    USER_OCID=$(grep "^user=" ~/.oci/config | cut -d'=' -f2)
    TENANCY_OCID=$(grep "^tenancy=" ~/.oci/config | cut -d'=' -f2)
    REGION=$(grep "^region=" ~/.oci/config | cut -d'=' -f2)
    FINGERPRINT=$(grep "^fingerprint=" ~/.oci/config | cut -d'=' -f2)
    KEY_FILE=$(grep "^key_file=" ~/.oci/config | cut -d'=' -f2)

    echo "OCI_CLI_USER:"
    echo "$USER_OCID"
    echo ""

    echo "OCI_CLI_TENANCY:"
    echo "$TENANCY_OCID"
    echo ""

    echo "OCI_CLI_REGION:"
    echo "$REGION"
    echo ""

    echo "OCI_CLI_FINGERPRINT:"
    echo "$FINGERPRINT"
    echo ""

    echo "OCI_CLI_KEY_CONTENT:"
    echo "(Copy the entire content below, including BEGIN/END lines)"
    echo "---"
    # Expand ~ in path
    KEY_PATH="${KEY_FILE/#\~/$HOME}"
    if [ -f "$KEY_PATH" ]; then
        cat "$KEY_PATH"
    else
        echo "⚠️  Key file not found at: $KEY_PATH"
    fi
    echo "---"
    echo ""
fi

echo "SSH_PUBLIC_KEY:"
cat ~/.ssh/oci-homelab.pub
echo ""

echo ""
echo "OCI_COMPARTMENT_ID:"
echo "⚠️  Get this from OCI Console → Identity → Compartments → Copy OCID"
echo ""

echo "======================================="
echo ""
echo "📝 Next steps:"
echo "1. Go to: https://github.com/SmadjaPaul/homelab/settings/secrets/actions"
echo "2. Add each secret listed above"
echo "3. Create 'production' environment: Settings → Environments → New environment"
echo "4. Push changes to trigger the workflow"
echo ""
echo "✅ Setup complete!"
