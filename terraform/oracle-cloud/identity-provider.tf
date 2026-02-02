# =============================================================================
# OCI Identity Provider for GitHub Actions OIDC
# Allows GitHub Actions to authenticate to OCI using OIDC tokens
# =============================================================================
#
# NOTE: OCI Identity Provider for OIDC must be configured via OCI Console or API,
# not via Terraform. This file is for reference/documentation purposes only.
#
# To configure the Identity Provider:
# 1. Log in to OCI Console
# 2. Navigate to: Identity & Security → Domains → Default Domain → Identity Providers
# 3. Create Identity Provider with:
#    - Protocol: SAML 2.0
#    - Metadata URL: https://token.actions.githubusercontent.com/.well-known/openid-configuration
#    - Audience: oci
# 4. Configure group mapping and IAM policies
#
# See: docs-site/docs/guides/oci-oidc-setup.md for detailed instructions
#
# The OIDC token exchange happens via API in the GitHub Actions workflow,
# not through Terraform resources.
