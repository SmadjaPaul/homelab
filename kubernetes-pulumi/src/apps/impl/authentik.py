"""
Custom implementation for Authentik.
Provisions a CloudNative-PG Cluster for its database and configures the Helm chart
to use the shared Redis instance and the newly created Postgres cluster.
"""

from typing import Any, Dict

import pulumi
import pulumi_kubernetes as k8s

from apps.generic import GenericHelmApp
from utils.schemas import AppModel

class AuthentikApp(GenericHelmApp):

    def deploy_components(self, provider: k8s.Provider, config: Dict[str, Any]) -> Dict[str, Any]:
        result = {}

        # 1. Create a CNPG Postgres Cluster for Authentik
        # Ensure the CNPG operator is running first (handled by topological sort + dependencies in apps.yaml)
        cluster_spec = {
            "instances": 2,
            "storage": {
                "size": "5Gi"
            }
        }

        if self._model.database_backup.enabled:
            cluster_spec["backup"] = {
                "barmanObjectStore": {
                    "destinationPath": f"s3://{self._model.database_backup.bucket}/{self._model.name}",
                    "endpointURL": self._model.database_backup.endpoint_url,
                    "s3Credentials": {
                        "accessKeyId": {
                            "name": self._model.database_backup.access_key_id,
                            "key": "access_key_id"
                        },
                        "secretAccessKey": {
                            "name": self._model.database_backup.secret_access_key,
                            "key": "secret_access_key"
                        }
                    },
                    "wal": {
                        "compression": "gzip"
                    }
                },
                "retentionPolicy": "30d"
            }

        pg_cluster = k8s.apiextensions.CustomResource(
            "authentik-db-cluster",
            api_version="postgresql.cnpg.io/v1",
            kind="Cluster",
            metadata={
                "name": "authentik-db",
                "namespace": self._model.namespace,
            },
            spec=cluster_spec,
            opts=pulumi.ResourceOptions(provider=provider),
        )
        result["db_cluster"] = pg_cluster

        # 2. Configure Helm values to disable embedded PG/Redis and use the external ones
        # The secret created by CNPG is named `<cluster-name>-app` (e.g. authentik-db-app)

        # We need to deeply merge the values
        custom_values = {
            "postgresql": {
                "enabled": False,
            },
            "redis": {
                "enabled": False,
            },
            "authentik": {
                "postgresql": {
                    "host": "authentik-db-rw", # CNPG read-write service name
                    "name": "app", # Default database name for CNPG
                    "user": "app",
                    # Password will be read from the secret by the chart if we configure existingSecret
                    "password": "none" # Placeholder, we might need env vars if chart doesn't support secretRef for pg password directly
                },
                "redis": {
                    # Redis is deployed in the 'storage' namespace as 'redis' (or whatever name the bitnami chart gives it, likely 'redis-master')
                    "host": "redis-master.storage.svc.cluster.local",
                }
            },
            "envValueFrom": {
                "AUTHENTIK_POSTGRESQL__PASSWORD": {
                    "secretKeyRef": {
                        "name": "authentik-db-app",
                        "key": "password"
                    }
                }
            }
        }

        # Deep merge with existing model values
        self._model.values = self._merge_dicts(self._model.values, custom_values)

        # 3. Deploy standard Helm chart
        helm_result = super().deploy_components(provider, config)
        result.update(helm_result)

        return result

    def _merge_dicts(self, dict1: Dict, dict2: Dict) -> Dict:
        """Deep merge two dictionaries."""
        result = dict1.copy()
        for key, value in dict2.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = self._merge_dicts(result[key], value)
            else:
                result[key] = value
        return result

def create_app(model: AppModel) -> AuthentikApp:
    return AuthentikApp(model)
