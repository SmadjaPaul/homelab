# GitOps Configuration - Non-sensitive OCI settings
# This file is safe to commit (no secrets)
# Sensitive values should be in terraform.tfvars (gitignored) or passed via environment variables

# TEMPORARY: Enable SSH from anywhere to allow GitHub Actions deployment
# After initial setup: set to false and configure admin_allowed_cidrs with your IP
allow_ssh_from_anywhere = true
