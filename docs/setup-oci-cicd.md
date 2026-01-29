# Setup Guide: Oracle Cloud CI/CD with GitHub Actions

This guide explains how to configure GitHub Actions to automatically deploy Oracle Cloud infrastructure.

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   GitHub    │────▶│  TFstate.dev│────▶│Oracle Cloud │
│   Actions   │     │  (State)    │     │  (Infra)    │
└─────────────┘     └─────────────┘     └─────────────┘
```

**State Management**: [TFstate.dev](https://tfstate.dev/) - Free Terraform state backend using GitHub token

## Prerequisites

- Oracle Cloud account (Always Free tier)
- GitHub repository with Actions enabled

## Step 1: Create OCI API Key

1. Go to Oracle Cloud Console: https://cloud.oracle.com
2. Click your profile icon (top right) → **My Profile**
3. Scroll to **API Keys** → **Add API Key**
4. Choose **Generate API Key Pair**
5. **Download Private Key** (save as `oci_api_key.pem`)
6. Click **Add**
7. Copy the **Configuration File Preview** - you'll need these values

Example configuration:
```ini
[DEFAULT]
user=ocid1.user.oc1..aaaaaaaxxxxxxxxxxxxxxxxxxxxxxx
fingerprint=12:34:56:78:90:ab:cd:ef:12:34:56:78:90:ab:cd:ef
tenancy=ocid1.tenancy.oc1..aaaaaaaxxxxxxxxxxxxxxxxxxxxxxx
region=eu-paris-1
key_file=<path to your private key>
```

## Step 2: Get Compartment OCID

1. Go to **Identity & Security** → **Compartments**
2. Click on your compartment (or root compartment)
3. Copy the **OCID**

## Step 3: Generate SSH Key

```bash
# Generate SSH key for instance access
ssh-keygen -t ed25519 -f ~/.ssh/oci-homelab -N ""

# Display public key (you'll need this)
cat ~/.ssh/oci-homelab.pub
```

## Step 4: Configure GitHub Secrets

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions**

Add these secrets:

| Secret Name | Value | How to get it |
|-------------|-------|---------------|
| `OCI_CLI_USER` | `ocid1.user.oc1..xxx` | From API Key config |
| `OCI_CLI_TENANCY` | `ocid1.tenancy.oc1..xxx` | From API Key config |
| `OCI_CLI_FINGERPRINT` | `12:34:56:...` | From API Key config |
| `OCI_CLI_REGION` | `eu-paris-1` | Your region |
| `OCI_CLI_KEY_CONTENT` | (entire private key) | Content of `oci_api_key.pem` |
| `OCI_COMPARTMENT_ID` | `ocid1.compartment.oc1..xxx` | From Step 2 |
| `SSH_PUBLIC_KEY` | `ssh-ed25519 AAAA...` | From Step 3 |

### Adding the Private Key

For `OCI_CLI_KEY_CONTENT`, paste the **entire content** of your private key file:

```
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC...
...
-----END PRIVATE KEY-----
```

## Step 5: Create GitHub Environment

1. Go to **Settings** → **Environments**
2. Click **New environment**
3. Name: `production`
4. Add protection rules (optional):
   - Required reviewers
   - Wait timer

## Step 6: Test the Workflow

1. Make a small change to any file in `terraform/oracle-cloud/`
2. Create a Pull Request
3. The workflow will run `terraform plan` and comment the results
4. Merge the PR to trigger `terraform apply`

## Workflow Behavior

| Trigger | Action |
|---------|--------|
| Pull Request | Plan only (comment on PR) |
| Push to main | Plan + Apply |
| Manual (workflow_dispatch) | Choose: plan, apply, or destroy |

## Free Tier Protection

The workflow includes a quota check that verifies:

- **OCPUs**: Maximum 4 (ARM)
- **Memory**: Maximum 24 GB (ARM)
- **Storage**: Maximum 200 GB

If you exceed these limits, the workflow will fail before applying.

## Manual Trigger

To manually run the workflow:

1. Go to **Actions** → **Terraform Oracle Cloud**
2. Click **Run workflow**
3. Choose action: `plan`, `apply`, or `destroy`

## Troubleshooting

### "Out of capacity" error

Oracle's free tier ARM instances are popular and may not be available. Solutions:
- Try a different availability domain
- Try at off-peak hours (early morning EU time)
- Wait and retry later

### Authentication errors

1. Verify all secrets are correctly set
2. Check the API key fingerprint matches
3. Ensure the private key content is complete (including headers)

### State file issues

State is managed by [TFstate.dev](https://tfstate.dev/):
- Uses `GITHUB_TOKEN` automatically in Actions
- Encrypted storage with AWS S3 + KMS
- State locking included
- No additional setup required

For local development:
```bash
export TF_HTTP_PASSWORD="ghp_your_personal_access_token"
terraform init
```

## Alternative: Spacelift

[Spacelift](https://spacelift.io/pricing) offers a free tier that includes:
- 1 private worker
- Unlimited public repos
- State management
- Policy as code

Consider Spacelift if you need more advanced CI/CD features.

## Security Notes

- Never commit `terraform.tfvars` with real values
- Never commit private keys or API tokens
- Use GitHub Secrets for all sensitive values
- The `production` environment adds an extra approval layer
