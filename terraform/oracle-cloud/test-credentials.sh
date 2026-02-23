#!/bin/bash
# Test OCI credentials script
# Usage: ./test-oci-credentials.sh

echo "=== Test des credentials OCI ==="
echo ""

# Check if running in CI or locally
if [ -n "$DOPPLER_TOKEN" ]; then
    echo "✓ DOPPLER_TOKEN is set"

    # Test Doppler connection
    echo ""
    echo "Testing Doppler connection..."
    doppler secrets --token "$DOPPLER_TOKEN" -p homelab -c prd 2>&1 | head -5
else
    echo "✗ DOPPLER_TOKEN is NOT set"
    echo "  Try: export DOPPLER_TOKEN=dp.pt.xxx"
fi

echo ""
echo "=== Vérification des secrets OCI ==="
echo ""

# Check environment variables
if [ -n "$OCI_CLI_TENANCY" ]; then
    echo "✓ OCI_CLI_TENANCY is set (${OCI_CLI_TENANCY:0:20}...)"
else
    echo "✗ OCI_CLI_TENANCY is NOT set"
fi

if [ -n "$OCI_CLI_USER" ]; then
    echo "✓ OCI_CLI_USER is set (${OCI_CLI_USER:0:20}...)"
else
    echo "✗ OCI_CLI_USER is NOT set"
fi

if [ -n "$OCI_CLI_FINGERPRINT" ]; then
    echo "✓ OCI_CLI_FINGERPRINT is set (${OCI_CLI_FINGERPRINT})"
else
    echo "✗ OCI_CLI_FINGERPRINT is NOT set"
fi

if [ -n "$OCI_CLI_KEY_CONTENT" ]; then
    KEY_LEN=${#OCI_CLI_KEY_CONTENT}
    echo "✓ OCI_CLI_KEY_CONTENT is set (length: $KEY_LEN)"
else
    echo "✗ OCI_CLI_KEY_CONTENT is NOT set"
fi

echo ""
echo "=== Solution temporaire ==="
echo "Si les variables Doppler ne fonctionnent pas, utilisez les variables d'environnement OCI:"
echo ""
echo "export OCI_CLI_TENANCY=ocid1.tenancy.oc1..aaaaaaaaxxx"
echo "export OCI_CLI_USER=ocid1.user.oc1..aaaaaaaaxxx"
echo "export OCI_CLI_FINGERPRINT=xx:xx:xx:xx:xx:xx:xx"
echo 'export OCI_CLI_KEY_CONTENT="<paste-your-private-key-here>"'
echo ""
echo "Puis relancez: terraform plan"
echo ""
echo "Terraform utilisera automatiquement ces variables si Doppler échoue."
