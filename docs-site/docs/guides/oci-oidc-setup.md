# OCI OIDC Authentication Setup for GitHub Actions

This guide explains how to configure OCI OIDC (OpenID Connect) authentication for GitHub Actions, following Oracle's recommended security practices.

## Overview

OCI OIDC authentication allows GitHub Actions to authenticate to OCI without storing long-lived API keys. Instead, GitHub generates short-lived OIDC tokens that are exchanged for OCI User Principal Session Tokens (UPST).

## Benefits

- **No long-lived credentials**: Eliminates the need to store API keys in GitHub Secrets
- **Short-lived tokens**: UPST tokens expire automatically (typically 1 hour)
- **Scope-specific**: Each workflow execution gets unique, narrowly-scoped tokens
- **More secure**: Reduces risk of credential exposure

## Prerequisites

1. OCI account with appropriate permissions
2. GitHub repository with Actions enabled
3. OCI CLI installed locally (for initial setup)

## Step 1: Configure OCI Identity Provider

1. **Log in to OCI Console**
   - Navigate to: Identity & Security → Domains → Default Domain → Identity Providers

2. **Create Identity Provider**
   - Click "Create Identity Provider"
   - Select "SAML 2.0" protocol
   - Name: `github-actions-oidc`
   - Description: `GitHub Actions OIDC Identity Provider`

3. **Configure GitHub OIDC Trust**
   - **Metadata URL**: `https://token.actions.githubusercontent.com/.well-known/openid-configuration`
   - **Audience**: `oci` (or your custom audience)
   - **Subject Claim**: `sub` (GitHub repository identifier)

4. **Configure Attribute Mapping**
   - Map GitHub claims to OCI user attributes
   - Repository: `repository`
   - Ref: `ref`
   - Workflow: `workflow`

5. **Create Group Mapping**
   - Create a group in OCI (e.g., `github-actions-users`)
   - Map GitHub repository to this group
   - Assign appropriate IAM policies to the group

## Step 2: Configure GitHub Actions Workflow

The workflows are already configured to use OIDC authentication. Ensure your workflow includes:

```yaml
permissions:
  id-token: write  # Required for OIDC token exchange
  contents: read
```

## Step 3: Verify Configuration

1. **Check OIDC Token Exchange**
   - Run a workflow and check logs for "Using OIDC authentication (UPST)"
   - If you see "Falling back to API key authentication", the Identity Provider may not be configured correctly

2. **Monitor Token Usage**
   - Check OCI Audit logs for authentication events
   - Verify tokens are being exchanged successfully

## Troubleshooting

### OIDC Token Exchange Fails

If OIDC token exchange fails, the workflow will automatically fall back to API key authentication. Common issues:

1. **Identity Provider not configured**: Ensure the Identity Provider is created and active in OCI Console
2. **Incorrect audience**: Verify the audience matches what's configured in OCI
3. **Group mapping**: Ensure the GitHub repository is mapped to a group with appropriate permissions

### Fallback to API Key

The workflow automatically falls back to API key authentication if:
- OIDC token exchange fails
- Identity Provider is not configured
- Token exchange endpoint returns an error

This ensures workflows continue to function even if OIDC is not fully configured.

## Migration from API Key to OIDC

1. Configure OCI Identity Provider (Step 1)
2. Update workflows to include `id-token: write` permission
3. Workflows will automatically use OIDC when available
4. Monitor logs to verify OIDC is being used
5. Once verified, you can optionally remove API key secrets (not recommended as fallback)

## References

- [Oracle Documentation: GitHub Actions OIDC](https://www.ateam-oracle.com/github-actions-oci-a-guide-to-secure-oidc-token-exchange)
- [OCI Token Exchange API](https://docs.oracle.com/en-us/iaas/Content/Identity/api-getstarted/json_web_token_exchange.htm)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-cloud-providers)
