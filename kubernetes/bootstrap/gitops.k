# Flux GitOps Configuration
# ========================
# Creates GitRepository and Kustomization for automatic reconciliation
#
# Usage:
#   kcl run bootstrap/gitops/main.k | kubectl apply -f-

repoUrl = "https://github.com/pauldouane/homelab"
branch = "main"
path = "kubernetes/apps"

# GitRepository
gitRepository = {
    "apiVersion": "source.toolkit.fluxcd.io/v1"
    "kind": "GitRepository"
    "metadata": {"name": "homelab"}
    "spec": {
        "url": repoUrl
        "ref": {"branch": branch}
        "interval": "1m"
    }
}

# Kustomization for all apps
kustomization = {
    "apiVersion": "kustomize.toolkit.fluxcd.io/v1"
    "kind": "Kustomization"
    "metadata": {"name": "apps", "namespace": "flux-system"}
    "spec": {
        "sourceRef": {
            "kind": "GitRepository"
            "name": "homelab"
        }
        "path": path
        "prune": True
        "validation": "client"
        "interval": "10m"
    }
}

# Output all resources as a list
items = [gitRepository, kustomization]
