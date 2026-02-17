# Automation Tenant Shared Configuration
# ================================

tenantName = "automation"

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
