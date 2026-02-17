# Bootstrap Configuration - Step 1: Namespace and CRDs
# =====================
# Flux CD + External Secrets Operator
#
# This file creates the namespace and applies Flux CRDs
# Usage:
#   kcl run bootstrap/main.k | kubectl apply -f-

items = [
    {
        "apiVersion": "v1"
        "kind": "Namespace"
        "metadata": {"name": "flux-system"}
    }
    {
        "apiVersion": "v1"
        "kind": "Namespace"
        "metadata": {"name": "kube-system"}
    }
    {
        "apiVersion": "v1"
        "kind": "Namespace"
        "metadata": {"name": "kube"}
    }
]
