# O11y Tenant Shared Configuration
# ================================

tenantName = "o11y"

tenantNamespace = {
    "apiVersion": "v1"
    "kind": "Namespace"
    "metadata": {"name": tenantName}
}

tenantSecretStore = {
    "apiVersion": "external-secrets.io/v1beta1"
    "kind": "ClusterSecretStore"
    "metadata": {
        "name": "{}-doppler".format(tenantName)
        "labels": {"tenant": tenantName}
    }
    "spec": {
        "provider": {
            "doppler": {
                "auth": {
                    "secretRef": {
                        "dopplerToken": {
                            "name": "doppler-credentials"
                            "namespace": "kube-system"
                            "key": "token"
                        }
                    }
                }
            }
        }
    }
}

result = [tenantNamespace, tenantSecretStore]
