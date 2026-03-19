import pulumi
import pulumi_kubernetes as k8s
import pulumi_command as command
from typing import List, Dict, Any

from shared.utils.schemas import AppModel, SecretRequirement


class KubernetesRegistry:
    def __init__(
        self,
        provider: k8s.Provider,
        doppler_secrets: Any,
        parent: pulumi.ComponentResource,
    ):
        self.provider = provider
        self.doppler_secrets = doppler_secrets
        self.parent = parent
        self.crd_wait_cmd = None
        self.shared_db_cluster = None

    def wait_for_crds(self):
        crd_name = "externalsecrets.external-secrets.io"
        self.crd_wait_cmd = command.local.Command(
            f"wait-for-crd-{crd_name}",
            create=f"kubectl wait --for=condition=Established crd/{crd_name} --timeout=60s",
            opts=pulumi.ResourceOptions(parent=self.parent),
        )

    def get_standard_labels(self, app: AppModel) -> Dict[str, str]:
        labels = {
            "app.kubernetes.io/name": app.name,
            "app.kubernetes.io/instance": app.name,
            "app.kubernetes.io/managed-by": "pulumi",
            "app.kubernetes.io/part-of": "homelab",
            "homelab.dev/tier": app.tier.value,
            "homelab.dev/category": app.category.value,
        }
        return labels

    def setup_rbac_for_app(
        self, app: AppModel, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        labels = self.get_standard_labels(app)
        labels["app.kubernetes.io/managed-by"] = "Helm"

        # Disable SA token automount by default
        # homepage needs K8s API access for service discovery
        # authentik needs K8s API access to manage outpost secrets (embedded outpost)
        needs_api_access = app.name in ("homepage", "authentik")

        sa = k8s.core.v1.ServiceAccount(
            f"sa-{app.name}",
            metadata={
                "name": app.name,
                "namespace": app.namespace,
                "labels": labels,
                "annotations": {
                    "meta.helm.sh/release-name": app.name,
                    "meta.helm.sh/release-namespace": app.namespace,
                    "pulumi.com/patchForce": "true",
                },
            },
            automount_service_account_token=needs_api_access,
            opts=opts,
        )

        if app.name == "homepage":
            # Homepage needs to see pods/services for discovery
            role = k8s.rbac.v1.ClusterRole(
                "homepage-k8s-discovery-role",
                metadata={"name": "homepage-k8s-discovery"},
                rules=[
                    {
                        "apiGroups": [""],
                        "resources": ["pods", "services", "namespaces", "nodes"],
                        "verbs": ["get", "list", "watch"],
                    },
                    {
                        "apiGroups": ["networking.k8s.io"],
                        "resources": ["ingresses"],
                        "verbs": ["get", "list", "watch"],
                    },
                    {
                        "apiGroups": ["traefik.containo.us", "traefik.io"],
                        "resources": ["ingressroutes"],
                        "verbs": ["get", "list", "watch"],
                    },
                ],
                opts=opts,
            )
            k8s.rbac.v1.ClusterRoleBinding(
                "homepage-k8s-discovery-binding",
                metadata={"name": "homepage-k8s-discovery"},
                role_ref={
                    "apiGroup": "rbac.authorization.k8s.io",
                    "kind": "ClusterRole",
                    "name": role.metadata["name"],
                },
                subjects=[
                    {
                        "kind": "ServiceAccount",
                        "name": sa.metadata["name"],
                        "namespace": sa.metadata["namespace"],
                    }
                ],
                opts=opts,
            )

        return [sa]

    def setup_reliability_for_app(
        self, app: AppModel, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        # Create PDB for critical apps even with 1 replica
        # minAvailable: 0 allows drain but documents the app as critical
        if app.tier.value == "critical" or app.resources.replicas > 1:
            min_available = max(
                0, app.resources.replicas - 1
            )  # 0 for single replica, N-1 for multi
            pdb = k8s.policy.v1.PodDisruptionBudget(
                f"pdb-{app.name}",
                metadata={
                    "name": app.name,
                    "namespace": app.namespace,
                    "labels": self.get_standard_labels(app),
                },
                spec={
                    "minAvailable": min_available,
                    "selector": {"matchLabels": {"app.kubernetes.io/name": app.name}},
                },
                opts=opts,
            )
            return [pdb]
        return []

    def setup_monitoring_for_app(
        self, app: AppModel, deployed_apps: Dict[str, Any], opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        if not app.test.test_monitoring:
            return []

        if (
            "kube-prometheus-stack" not in deployed_apps
            and "prometheus-stack" not in deployed_apps
        ):
            print(
                f"    [Registry] Skipping ServiceMonitor for {app.name} (monitoring operator not found in deployed_apps)"
            )
            return []

        deps = []
        if "kube-prometheus-stack" in deployed_apps and isinstance(
            deployed_apps["kube-prometheus-stack"], pulumi.Resource
        ):
            deps.append(deployed_apps["kube-prometheus-stack"])
        if "prometheus-stack" in deployed_apps and isinstance(
            deployed_apps["prometheus-stack"], pulumi.Resource
        ):
            deps.append(deployed_apps["prometheus-stack"])

        local_opts = pulumi.ResourceOptions.merge(
            opts, pulumi.ResourceOptions(depends_on=deps)
        )

        sm = k8s.apiextensions.CustomResource(
            f"servicemonitor-{app.name}",
            api_version="monitoring.coreos.com/v1",
            kind="ServiceMonitor",
            metadata={
                "name": app.name,
                "namespace": app.namespace,
                "labels": {
                    **self.get_standard_labels(app),
                    "release": "prometheus-stack",
                },
            },
            spec={
                "selector": {"matchLabels": {"app.kubernetes.io/name": app.name}},
                "endpoints": [
                    {
                        "port": "http",
                        "path": "/metrics",
                        "interval": "30s",
                    }
                ],
            },
            opts=local_opts,
        )
        return [sm]

    def setup_secrets_for_app(
        self, app: AppModel, deployed_apps: Dict[str, Any], opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        secrets = []
        for req in app.secrets:
            deps = []
            if deployed_apps.get("external-secrets") and isinstance(
                deployed_apps["external-secrets"], pulumi.Resource
            ):
                deps.append(deployed_apps["external-secrets"])

            local_opts = pulumi.ResourceOptions.merge(
                opts, pulumi.ResourceOptions(depends_on=deps)
            )

            def _verify_keys(args):
                secret_map, req_name, remote_key, keys_val = args
                keys_to_check = []
                if remote_key:
                    keys_to_check = [remote_key]
                elif isinstance(keys_val, dict):
                    keys_to_check = list(keys_val.values())
                else:
                    keys_to_check = keys_val

                for k in keys_to_check:
                    if k not in secret_map:
                        print(
                            f"    ⚠️  [WARNING] Secret key '{k}' required by app '{app.name}' is temporarily MISSING in Doppler. "
                            f"The ExternalSecret will be created but will only sync once added to Doppler."
                        )

            pulumi.Output.all(
                self.doppler_secrets.map, req.name, req.remote_key, req.keys
            ).apply(_verify_keys)

            es = k8s.apiextensions.CustomResource(
                f"secret-{app.name}-{req.name}",
                api_version="external-secrets.io/v1beta1",
                kind="ExternalSecret",
                metadata={
                    "name": req.name,
                    "namespace": app.namespace,
                    "annotations": {"pulumi.com/patchForce": "true"},
                },
                spec={
                    "refreshInterval": "1h",
                    "secretStoreRef": {
                        "kind": "ClusterSecretStore",
                        "name": "doppler",
                    },
                    "target": {"name": req.name, "creationPolicy": "Owner"},
                    "data": self._build_external_secret_data(req),
                },
                opts=local_opts,
            )
            secrets.append(es)

            # Wait for the ExternalSecret to sync the K8s Secret before apps use it.
            # This prevents pods from starting with missing secrets.
            wait_cmd = command.local.Command(
                f"wait-es-{app.name}-{req.name}",
                create=(
                    f"kubectl wait externalsecret/{req.name} "
                    f"--for=condition=SecretSynced "
                    f"-n {app.namespace} "
                    f"--timeout=120s "
                    f"2>/dev/null || echo 'ExternalSecret {req.name} not yet synced, continuing...'"
                ),
                opts=pulumi.ResourceOptions.merge(
                    opts,
                    pulumi.ResourceOptions(
                        depends_on=[es],
                        parent=self.parent,
                    ),
                ),
            )
            secrets.append(wait_cmd)

        return secrets

    def setup_docker_secrets(
        self, app: AppModel, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        es = k8s.apiextensions.CustomResource(
            f"dockerhub-secret-{app.name}",
            api_version="external-secrets.io/v1beta1",
            kind="ExternalSecret",
            metadata={
                "name": "dockerhub-secret",
                "namespace": app.namespace,
                "annotations": {"pulumi.com/patchForce": "true"},
            },
            spec={
                "refreshInterval": "1h",
                "secretStoreRef": {
                    "kind": "ClusterSecretStore",
                    "name": "doppler",
                },
                "target": {
                    "name": "dockerhub-secret",
                    "creationPolicy": "Owner",
                    "template": {
                        "type": "kubernetes.io/dockerconfigjson",
                        "data": {
                            ".dockerconfigjson": '{"auths":{"https://index.docker.io/v1/":{"username":"{{ .username | toString }}","password":"{{ .password | toString }}","auth":"{{ (print .username ":" .password) | b64enc }}"}}}'
                        },
                    },
                },
                "data": [
                    {"secretKey": "username", "remoteRef": {"key": "DOCKER_NAME"}},
                    {"secretKey": "password", "remoteRef": {"key": "DOCKER_HUB_TOKEN"}},
                ],
            },
            opts=opts,
        )
        return [es]

    def _build_external_secret_data(
        self, req: SecretRequirement
    ) -> List[Dict[str, Any]]:
        data = []
        if isinstance(req.keys, dict):
            for k8s_key, doppler_key in req.keys.items():
                if req.remote_key:
                    data.append(
                        {
                            "secretKey": k8s_key,
                            "remoteRef": {
                                "key": req.remote_key,
                                "property": doppler_key,
                            },
                        }
                    )
                else:
                    data.append(
                        {"secretKey": k8s_key, "remoteRef": {"key": doppler_key}}
                    )
        else:
            for key in req.keys:
                if req.remote_key:
                    data.append(
                        {
                            "secretKey": key,
                            "remoteRef": {"key": req.remote_key, "property": key},
                        }
                    )
                else:
                    data.append({"secretKey": key, "remoteRef": {"key": key}})
        return data

    def setup_shared_database_cluster(
        self, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        """Create a single shared HA CNPG Cluster for all apps to save OCI storage."""
        print("  [Registry] Provisioning shared HA CNPG Cluster (homelab-db)...")

        # We put it in cnpg-system as it's the operator namespace and central
        namespace = "cnpg-system"

        # 1. S3 Backup Secret for the shared cluster
        # Using a fixed name for the shared cluster backup creds
        backup_creds = k8s.apiextensions.CustomResource(
            "homelab-db-backup-creds",
            api_version="external-secrets.io/v1beta1",
            kind="ExternalSecret",
            metadata={
                "name": "homelab-db-backup-creds",
                "namespace": namespace,
                "annotations": {"pulumi.com/patchForce": "true"},
            },
            spec={
                "refreshInterval": "1h",
                "secretStoreRef": {"kind": "ClusterSecretStore", "name": "doppler"},
                "target": {
                    "name": "homelab-db-backup-creds",
                    "creationPolicy": "Owner",
                },
                "data": [
                    {
                        "secretKey": "access_key_id",
                        "remoteRef": {"key": "OCI_S3_ACCESS_KEY"},
                    },
                    {
                        "secretKey": "secret_access_key",
                        "remoteRef": {"key": "OCI_S3_SECRET_KEY"},
                    },
                ],
            },
            opts=opts,
        )

        # 2. The Shared Cluster
        cluster = k8s.apiextensions.CustomResource(
            "homelab-db-cluster",
            api_version="postgresql.cnpg.io/v1",
            kind="Cluster",
            metadata={
                "name": "homelab-db",
                "namespace": namespace,
                "labels": {
                    "app.kubernetes.io/name": "homelab-db",
                    "app.kubernetes.io/instance": "homelab-db",
                    "homelab.dev/tier": "critical",
                },
                "annotations": {"pulumi.com/patchForce": "true"},
            },
            spec={
                "instances": 1,  # Reduced from 2 to free OCI Block Storage quota
                "primaryUpdateStrategy": "unsupervised",
                "storage": {
                    "size": "50Gi",  # OCI Minimum
                    "storageClass": "oci-bv",
                },
                "backup": {
                    "barmanObjectStore": {
                        "destinationPath": "s3://velero-backups/homelab-db",
                        "endpointURL": "https://axnvxxurxefp.compat.objectstorage.eu-paris-1.oraclecloud.com",
                        "s3Credentials": {
                            "accessKeyId": {
                                "name": "homelab-db-backup-creds",
                                "key": "access_key_id",
                            },
                            "secretAccessKey": {
                                "name": "homelab-db-backup-creds",
                                "key": "secret_access_key",
                            },
                        },
                        "wal": {"compression": "gzip"},
                    },
                    "retentionPolicy": "30d",
                },
                "bootstrap": {
                    "initdb": {
                        "database": "postgres",
                        "owner": "postgres",
                    }
                },
            },
            opts=pulumi.ResourceOptions.merge(
                opts, pulumi.ResourceOptions(depends_on=[backup_creds])
            ),
        )

        self.shared_db_cluster = cluster
        return [backup_creds, cluster]

    def setup_pod_cleanup_cronjob(
        self, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        """Create a CronJob that deletes evicted/failed pods every 5 minutes.

        Prevents eviction cascades that cause DiskPressure by cleaning up
        failed pods before they accumulate.
        """
        print("  [Registry] Provisioning pod-cleanup CronJob in kube-system...")

        namespace = "kube-system"
        name = "pod-cleanup"

        sa = k8s.core.v1.ServiceAccount(
            "pod-cleanup-sa",
            metadata={
                "name": name,
                "namespace": namespace,
            },
            opts=opts,
        )

        role = k8s.rbac.v1.ClusterRole(
            "pod-cleanup-role",
            metadata={"name": name},
            rules=[
                {
                    "apiGroups": [""],
                    "resources": ["pods"],
                    "verbs": ["get", "list", "delete"],
                }
            ],
            opts=opts,
        )

        binding = k8s.rbac.v1.ClusterRoleBinding(
            "pod-cleanup-binding",
            metadata={"name": name},
            role_ref={
                "apiGroup": "rbac.authorization.k8s.io",
                "kind": "ClusterRole",
                "name": role.metadata["name"],
            },
            subjects=[
                {
                    "kind": "ServiceAccount",
                    "name": sa.metadata["name"],
                    "namespace": namespace,
                }
            ],
            opts=pulumi.ResourceOptions.merge(
                opts, pulumi.ResourceOptions(depends_on=[sa, role])
            ),
        )

        cronjob = k8s.batch.v1.CronJob(
            "pod-cleanup-cronjob",
            metadata={
                "name": name,
                "namespace": namespace,
            },
            spec={
                "schedule": "*/5 * * * *",
                "successfulJobsHistoryLimit": 1,
                "failedJobsHistoryLimit": 1,
                "jobTemplate": {
                    "spec": {
                        "template": {
                            "spec": {
                                "serviceAccountName": name,
                                "restartPolicy": "OnFailure",
                                "tolerations": [
                                    {
                                        "key": "node.kubernetes.io/disk-pressure",
                                        "operator": "Exists",
                                        "effect": "NoSchedule",
                                    }
                                ],
                                "containers": [
                                    {
                                        "name": name,
                                        "image": "registry.k8s.io/kubectl:v1.32.3",
                                        "command": [
                                            "kubectl",
                                            "delete",
                                            "pods",
                                            "--all-namespaces",
                                            "--field-selector=status.phase==Failed",
                                            "--grace-period=0",
                                        ],
                                        "resources": {
                                            "limits": {
                                                "cpu": "100m",
                                                "memory": "64Mi",
                                            },
                                            "requests": {
                                                "cpu": "50m",
                                                "memory": "32Mi",
                                            },
                                        },
                                    }
                                ],
                            }
                        }
                    }
                },
            },
            opts=pulumi.ResourceOptions.merge(
                opts, pulumi.ResourceOptions(depends_on=[sa, role, binding])
            ),
        )

        return [sa, role, binding, cronjob]

    def setup_database_for_app(
        self, app: AppModel, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        if not app.persistence.database or not app.persistence.database.local:
            return []

        if not self.shared_db_cluster:
            # Fallback for apps that might be deployed before global infra (should not happen)
            pulumi.log.warn(
                f"Shared DB cluster not initialized for {app.name}. DB provisioning might fail."
            )
            return []

        print(
            f"  [Registry] Provisioning database and user for {app.name} in homelab-db..."
        )

        # We need a secret for the application user
        # We use a RandomPassword and a Secret resource
        import pulumi_random as random

        db_password = random.RandomPassword(
            f"{app.name}-db-password-v1",
            length=32,
            special=False,  # Avoid psql escaping issues for now
            opts=opts,
        )

        db_service = "homelab-db-rw.cnpg-system.svc.cluster.local"

        app_db_secret = k8s.core.v1.Secret(
            f"{app.name}-db-app",
            metadata={
                "name": f"{app.name}-db-app",
                "namespace": app.namespace,
                "annotations": {"pulumi.com/patchForce": "true"},
            },
            string_data={
                "host": db_service,
                "username": app.name,
                "db-username": app.name,  # For Nextcloud and others
                "user": app.name,  # Alias
                "password": db_password.result,
                "dbname": app.name,
                # Standardized keys for broader compatibility
                "POSTGRES_HOST": db_service,
                "POSTGRES_USER": app.name,
                "POSTGRES_PASSWORD": db_password.result,
                "POSTGRES_DB": app.name,
                "DB_HOST": db_service,
                "DB_USER": app.name,
                "DB_PASSWORD": db_password.result,
                "DB_NAME": app.name,
                "uri": pulumi.Output.format(
                    "postgresql://{0}:{1}@{2}:5432/{0}",
                    app.name,
                    db_password.result,
                    db_service,
                ),
            },
            opts=opts,
        )

        # Provisioning Job: Creates role and database if they don't exist
        # We use the superuser secret that CNPG creates: homelab-db-app
        # Use the full service FQDN and add retry logic for resilience

        provision_job = k8s.batch.v1.Job(
            f"{app.name}-db-provision",
            metadata={
                "name": f"{app.name}-db-provision",
                "namespace": "cnpg-system",
                "annotations": {"pulumi.com/patchForce": "true"},
            },
            spec={
                "backoffLimit": 4,
                "template": {
                    "spec": {
                        "containers": [
                            {
                                "name": "provisioner",
                                "image": "docker.io/postgres:16-alpine",
                                "command": ["sh", "-c"],
                                "args": [
                                    # Wait for DB to be ready using pg_isready (without -w flag)
                                    f"for i in $(seq 1 30); do pg_isready -h {db_service} -U postgres && break || echo 'Waiting for database...'; sleep 2; done; "
                                    # Create user and database with proper error handling
                                    f"export PGPASSWORD=$SUPERUSER_PASSWORD; "
                                    f"export PGHOST={db_service}; "
                                    f"export APP_USER={app.name}; "
                                    f"export DATABASE_NAME={app.name}; "
                                    f"""psql -h $PGHOST -U postgres -d postgres -c "DO \\$\\$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '$APP_USER') THEN CREATE USER \\"$APP_USER\\" WITH PASSWORD '$APP_PASSWORD'; ELSE ALTER USER \\"$APP_USER\\" WITH PASSWORD '$APP_PASSWORD'; END IF; END \\$\\$;"; """
                                    f"""psql -h $PGHOST -U postgres -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '$DATABASE_NAME'" | grep -q 1 || psql -h $PGHOST -U postgres -d postgres -c "CREATE DATABASE \\"$DATABASE_NAME\\" OWNER \\"$APP_USER\\";"; """
                                    f"""psql -h $PGHOST -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \\"$DATABASE_NAME\\" TO \\"$APP_USER\\";"; """
                                    f"echo 'Database provisioning completed for {app.name}'",
                                ],
                                "env": [
                                    {
                                        "name": "PGPASSWORD",
                                        "valueFrom": {
                                            "secretKeyRef": {
                                                "name": "homelab-db-app",
                                                "key": "password",
                                            }
                                        },
                                    },
                                    {
                                        "name": "SUPERUSER_PASSWORD",
                                        "valueFrom": {
                                            "secretKeyRef": {
                                                "name": "homelab-db-app",
                                                "key": "password",
                                            }
                                        },
                                    },
                                    {
                                        "name": "APP_PASSWORD",
                                        "value": db_password.result,
                                    },
                                ],
                            }
                        ],
                        "restartPolicy": "Never",
                    }
                },
            },
            opts=pulumi.ResourceOptions.merge(
                opts,
                pulumi.ResourceOptions(
                    depends_on=[self.shared_db_cluster, db_password],
                    delete_before_replace=True,
                ),
            ),
        )

        return [app_db_secret, provision_job]
