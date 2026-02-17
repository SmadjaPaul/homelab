# Flux GitOps Configuration
# ========================
# Creates GitRepository for automatic reconciliation
# Note: KCL files are compiled and applied via GitHub Actions
#
# Usage:
#   kcl run bootstrap/gitops/main.k | kubectl apply -f-

repoUrl = "https://github.com/SmadjaPaul/homelab"
branch = "main"

# GitRepository - tracks the repository for Flux to monitor
gitRepository = {
    "apiVersion": "source.toolkit.fluxcd.io/v1"
    "kind": "GitRepository"
    "metadata": {"name": "homelab", "namespace": "flux-system"}
    "spec": {
        "url": repoUrl
        "ref": {"branch": branch}
        "interval": "1m"
    }
}

# Output all resources as a list
items = [gitRepository]
