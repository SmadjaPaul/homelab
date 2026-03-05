"""
Custom implementation for Authentik.
Provisions a CloudNative-PG Cluster for its database and configures the Helm chart
to use the shared Redis instance and the newly created Postgres cluster.
"""

from typing import Any, Dict, Optional

import pulumi
import pulumi_kubernetes as k8s

from shared.apps.generic import GenericHelmApp
from shared.utils.schemas import AppModel


class AuthentikApp(GenericHelmApp):
    def get_final_values(self) -> Dict[str, Any]:
        """Provides the final dictionary of Helm values specifically for Authentik."""
        # Start with base values from GenericHelmApp
        base_values = super().get_final_values()

        # 2. Configure Helm values to disable embedded PG/Redis and use the external ones
        # Use self._model.name for DB user/name to match CNPG's automatic setup
        db_user = self._model.name
        db_name = self._model.name
        db_host = f"{self._model.name}-db-rw.{self._model.namespace}.svc.cluster.local"

        custom_values = {
            "postgresql": {
                "enabled": False,
            },
            "redis": {
                "enabled": False,
            },
            "authentik": {
                "redis": {
                    "host": "redis.storage.svc.cluster.local",
                    "port": 6379,
                },
                "existingSecret": {"secretName": "authentik-vars"},
            },
            "server": {
                "env": [
                    {
                        "name": "AUTHENTIK_REDIS__HOST",
                        "value": "redis.storage.svc.cluster.local",
                    },
                    {"name": "AUTHENTIK_POSTGRESQL__HOST", "value": db_host},
                    {"name": "AUTHENTIK_POSTGRESQL__NAME", "value": db_name},
                    {"name": "AUTHENTIK_POSTGRESQL__USER", "value": db_user},
                    {"name": "AUTHENTIK_POSTGRESQL__PORT", "value": "5432"},
                    {
                        "name": "AUTHENTIK_REDIS__PASSWORD",
                        "valueFrom": {
                            "secretKeyRef": {
                                "name": "authentik-vars",
                                "key": "AUTHENTIK_REDIS_PASSWORD",
                            }
                        },
                    },
                    {
                        "name": "AUTHENTIK_POSTGRESQL__PASSWORD",
                        "valueFrom": {
                            "secretKeyRef": {
                                "name": "authentik-db-app",
                                "key": "password",
                            }
                        },
                    },
                    {
                        "name": "AUTHENTIK_BOOTSTRAP_PASSWORD",
                        "valueFrom": {
                            "secretKeyRef": {
                                "name": "authentik-vars",
                                "key": "AUTHENTIK_BOOTSTRAP_PASSWORD",
                            }
                        },
                    },
                    {
                        "name": "AUTHENTIK_BOOTSTRAP_TOKEN",
                        "valueFrom": {
                            "secretKeyRef": {
                                "name": "authentik-vars",
                                "key": "AUTHENTIK_BOOTSTRAP_TOKEN",
                            }
                        },
                    },
                ]
            },
            "worker": {
                "env": [
                    {
                        "name": "AUTHENTIK_REDIS__HOST",
                        "value": "redis.storage.svc.cluster.local",
                    },
                    {"name": "AUTHENTIK_POSTGRESQL__HOST", "value": db_host},
                    {"name": "AUTHENTIK_POSTGRESQL__NAME", "value": db_name},
                    {"name": "AUTHENTIK_POSTGRESQL__USER", "value": db_user},
                    {"name": "AUTHENTIK_POSTGRESQL__PORT", "value": "5432"},
                    {
                        "name": "AUTHENTIK_REDIS__PASSWORD",
                        "valueFrom": {
                            "secretKeyRef": {
                                "name": "authentik-vars",
                                "key": "AUTHENTIK_REDIS_PASSWORD",
                            }
                        },
                    },
                    {
                        "name": "AUTHENTIK_POSTGRESQL__PASSWORD",
                        "valueFrom": {
                            "secretKeyRef": {
                                "name": "authentik-db-app",
                                "key": "password",
                            }
                        },
                    },
                    {
                        "name": "AUTHENTIK_BOOTSTRAP_PASSWORD",
                        "valueFrom": {
                            "secretKeyRef": {
                                "name": "authentik-vars",
                                "key": "AUTHENTIK_BOOTSTRAP_PASSWORD",
                            }
                        },
                    },
                    {
                        "name": "AUTHENTIK_BOOTSTRAP_TOKEN",
                        "valueFrom": {
                            "secretKeyRef": {
                                "name": "authentik-vars",
                                "key": "AUTHENTIK_BOOTSTRAP_TOKEN",
                            }
                        },
                    },
                    # SMTP Configuration
                    {
                        "name": "AUTHENTIK_EMAIL__HOST",
                        "valueFrom": {
                            "secretKeyRef": {
                                "name": "authentik-vars",
                                "key": "AUTHENTIK_SMTP_HOST",
                            }
                        },
                    },
                    {
                        "name": "AUTHENTIK_EMAIL__PORT",
                        "valueFrom": {
                            "secretKeyRef": {
                                "name": "authentik-vars",
                                "key": "AUTHENTIK_SMTP_PORT",
                            }
                        },
                    },
                    {
                        "name": "AUTHENTIK_EMAIL__USERNAME",
                        "valueFrom": {
                            "secretKeyRef": {
                                "name": "authentik-vars",
                                "key": "AUTHENTIK_SMTP_USERNAME",
                            }
                        },
                    },
                    {
                        "name": "AUTHENTIK_EMAIL__PASSWORD",
                        "valueFrom": {
                            "secretKeyRef": {
                                "name": "authentik-vars",
                                "key": "AUTHENTIK_SMTP_PASSWORD",
                            }
                        },
                    },
                    {
                        "name": "AUTHENTIK_EMAIL__FROM",
                        "valueFrom": {
                            "secretKeyRef": {
                                "name": "authentik-vars",
                                "key": "AUTHENTIK_SMTP_FROM",
                            }
                        },
                    },
                    {"name": "AUTHENTIK_EMAIL__USE_TLS", "value": "true"},
                ]
            },
        }

        # Sync server env with worker env (they should be identical for core config)
        custom_values["server"]["env"] = custom_values["worker"]["env"]

        print(
            f"DEBUG AUTHENTIK: base_values server env exists? {'server' in base_values}"
        )
        print(
            f"DEBUG AUTHENTIK: custom_values server env count: {len(custom_values['server']['env'])}"
        )

        # 3. Handle Storage/Persistence mapping
        if self._model.storage:
            if "persistence" not in custom_values["authentik"]:
                custom_values["authentik"]["persistence"] = {}

            for storage in self._model.storage:
                if storage.name == "data":
                    custom_values["authentik"]["persistence"].update(
                        {"enabled": True, "existingClaim": f"{self._model.name}-data"}
                    )

        # Return merged values
        return self._merge_dicts(base_values, custom_values)

    def deploy_components(
        self,
        provider: k8s.Provider,
        config: Dict[str, Any],
        opts: Optional[pulumi.ResourceOptions] = None,
    ) -> Dict[str, Any]:
        result = {}

        # 1. Create a CNPG Postgres Cluster for Authentik
        cluster_spec = {
            "instances": 2,
            "storage": {"size": "5Gi", "storageClass": "local-path"},
        }

        if self._model.database_backup.enabled:
            cluster_spec["backup"] = {
                "barmanObjectStore": {
                    "destinationPath": f"s3://{self._model.database_backup.bucket}/{self._model.name}",
                    "endpointURL": self._model.database_backup.endpoint_url,
                    "s3Credentials": {
                        "accessKeyId": {
                            "name": self._model.database_backup.access_key_id,
                            "key": "access_key_id",
                        },
                        "secretAccessKey": {
                            "name": self._model.database_backup.secret_access_key,
                            "key": "secret_access_key",
                        },
                    },
                    "wal": {"compression": "gzip"},
                },
                "retentionPolicy": "30d",
            }

        cluster_spec["bootstrap"] = {
            "initdb": {
                "database": "authentik",
                "owner": "authentik",
            }
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

        # 2. Deploy standard Helm chart (it will call our get_final_values)
        helm_result = super().deploy_components(provider, config, opts=opts)
        result.update(helm_result)

        return result

    def _merge_dicts(self, dict1: Dict, dict2: Dict) -> Dict:
        """Deep merge two dictionaries."""
        result = dict1.copy()
        for key, value in dict2.items():
            if (
                key in result
                and isinstance(result[key], dict)
                and isinstance(value, dict)
            ):
                result[key] = self._merge_dicts(result[key], value)
            else:
                result[key] = value
        return result


def create_app(model: AppModel) -> AuthentikApp:
    return AuthentikApp(model)
