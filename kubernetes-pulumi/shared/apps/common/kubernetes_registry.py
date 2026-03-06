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

    def wait_for_crds(self):
        crd_name = "externalsecrets.external-secrets.io"
        self.crd_wait_cmd = command.local.Command(
            f"wait-for-crd-{crd_name}",
            create=f"kubectl wait --for=condition=Established crd/{crd_name} --timeout=60s",
            opts=pulumi.ResourceOptions(parent=self.parent),
        )

    def get_standard_labels(self, app: AppModel) -> Dict[str, str]:
        return {
            "app.kubernetes.io/name": app.name,
            "app.kubernetes.io/instance": app.name,
            "app.kubernetes.io/managed-by": "pulumi",
            "app.kubernetes.io/part-of": "homelab",
            "homelab.dev/tier": app.tier.value,
            "homelab.dev/category": app.category.value,
        }

    def setup_rbac_for_app(
        self, app: AppModel, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        labels = self.get_standard_labels(app)
        labels["app.kubernetes.io/managed-by"] = "Helm"

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
            opts=opts,
        )
        return [sa]

    def setup_reliability_for_app(
        self, app: AppModel, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        if app.replicas > 1:
            pdb = k8s.policy.v1.PodDisruptionBudget(
                f"pdb-{app.name}",
                metadata={
                    "name": app.name,
                    "namespace": app.namespace,
                    "labels": self.get_standard_labels(app),
                },
                spec={
                    "maxUnavailable": 1,
                    "selector": {"matchLabels": {"app.kubernetes.io/name": app.name}},
                },
                opts=opts,
            )
            return [pdb]
        return []

    def setup_monitoring_for_app(
        self, app: AppModel, deployed_apps: Dict[str, Any], opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        if not getattr(app, "monitoring", True):
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
                        raise ValueError(
                            f"CRITICAL ERROR: Secret key '{k}' required by app '{app.name}' is MISSING in Doppler (project: infrastructure, config: prd). Please add it in Doppler before deploying."
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

    def setup_database_for_app(
        self, app: AppModel, opts: pulumi.ResourceOptions
    ) -> List[pulumi.Resource]:
        if not app.database or not app.database.local:
            return []

        print(f"  [Registry] Provisioning local CNPG Cluster for {app.name}...")

        sc = app.database.storage_class or "local-path"

        db = k8s.apiextensions.CustomResource(
            f"db-{app.name}",
            api_version="postgresql.cnpg.io/v1",
            kind="Cluster",
            metadata={
                "name": f"{app.name}-db",
                "namespace": app.namespace,
                "labels": self.get_standard_labels(app),
            },
            spec={
                "instances": 2 if app.tier == "critical" else 1,
                "storage": {
                    "size": app.database.size,
                    "storageClass": sc,
                },
                "bootstrap": {
                    "initdb": {
                        "database": app.name,
                        "owner": app.name,
                    }
                },
            },
            opts=opts,
        )
        return [db]
