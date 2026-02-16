# =============================================================================
# OCI Identity Provider for GitHub Actions OIDC
# Allows GitHub Actions to authenticate to OCI using OIDC tokens
# =============================================================================
#
# CONFIGURATION COMPLETED:
# -----------------------
# Identity Propagation Trust and OAuth Application have been configured via CLI.
#
# Identity Propagation Trust:
#   - Name: GitHub-Actions-OIDC
#   - Issuer: https://token.actions.githubusercontent.com
#   - Type: JWT
#   - Public Key Endpoint: https://token.actions.githubusercontent.com/.well-known/jwks
#
# OAuth Application (GitHub-Actions-OIDC):
#   - Allowed Grants: jwt-bearer, client_credentials
#
# GitHub Secrets Required:
#   - OCI_DOMAIN_URL: (Identity Domain URL from OCI Console)
#   - OCI_OIDC_CLIENT_ID: (OAuth App Client ID from OCI Console)
#   - OCI_OIDC_CLIENT_SECRET: (OAuth App Client Secret from OCI Console)
#
# How it works:
#   1. GitHub Actions requests an OIDC token with audience "oci"
#   2. The token is exchanged via JWT Bearer grant at the Identity Domain
#   3. OCI returns an access token for API calls
#
# See: https://www.ateam-oracle.com/github-actions-oci-a-guide-to-secure-oidc-token-exchange
