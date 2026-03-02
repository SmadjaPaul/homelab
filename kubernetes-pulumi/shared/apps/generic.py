import pulumi
import pulumi_kubernetes as k8s
import pulumi_kubernetes.helm.v3 as helm
from typing import Optional, Dict, Any, List
from shared.apps.base import BaseApp
from shared.utils.schemas import AppModel
import yaml

class GenericHelmApp(BaseApp):
    def __init__(self, model: AppModel):
        super().__init__(model)

    def deploy_components(
        self,
        provider: k8s.Provider,
        config: dict[str, Any],
        opts: Optional[pulumi.ResourceOptions] = None
    ) -> dict[str, Any]:
        app_name = self._model.name
        chart_name = self._model.helm.chart
        chart_version = self._model.helm.version
        repo_url = self._model.helm.repo
        
        # Merge values
        final_values = self._model.helm.values.copy()
        
        # Mount additional storage volumes created by registry
        if self._model.storage:
            if 'persistence' not in final_values:
                final_values['persistence'] = {}
                
            for storage in self._model.storage:
                key = storage.name
                pvc_name = storage.existing_claim if hasattr(storage, 'existing_claim') and storage.existing_claim else f"{self._model.name}-{storage.name}"
                
                # 1. Skip if already defined in manually provided values
                if key in final_values.get('persistence', {}):
                    continue
                
                # 2. Check if a similar key (exact match or typical suffix) is already defined
                found_similar = False
                for existing_key in final_values.get('persistence', {}).keys():
                    if key.lower() == existing_key.lower() or existing_key.lower().endswith(key.lower()):
                        found_similar = True
                        break
                if found_similar:
                    continue

                # Smart mapping for BJW-S / Common app-template
                chart_version_str = str(self._model.helm.version)
                is_v3 = (self._model.helm.chart == "app-template" and chart_version_str.startswith("3.")) or \
                        (self._model.helm.chart == "navidrome" and chart_version_str.startswith("3."))
                
                if is_v3:
                    final_values['persistence'][key] = {
                        "enabled": True,
                        "type": "persistentVolumeClaim",
                        "existingClaim": pvc_name,
                    }
                elif app_name == "homarr" or chart_name == "homarr":
                    # Homarr 2.0.0 uses a different style
                    final_values['persistence'][key] = {
                        "enabled": True,
                        "type": "pvc",
                        "volumeClaimName": pvc_name,
                    }
                else:
                    final_values['persistence'][key] = {
                        "enabled": True,
                        "type": "pvc",
                        "existingClaim": pvc_name,
                    }

        # Automatically inject defined secrets via envFrom
        if self._model.secrets:
            env_from_item = [{"secretRef": {"name": req.name}} for req in self._model.secrets]
            
            # Authentik 2024.10+ uses global.envFrom
            if app_name == "authentik":
                if 'global' not in final_values: final_values['global'] = {}
                if 'envFrom' not in final_values['global']: final_values['global']['envFrom'] = []
                final_values['global']['envFrom'].extend(env_from_item)
            else:
                if 'global' not in final_values:
                    final_values['global'] = {}
                if 'envFrom' not in final_values['global']:
                    final_values['global']['envFrom'] = []
                final_values['global']['envFrom'].extend(env_from_item)

            if 'controllers' in final_values:
                for ctrl_name, ctrl_val in final_values['controllers'].items():
                    if 'containers' in ctrl_val:
                        for cont_name, cont_val in ctrl_val['containers'].items():
                            if 'envFrom' not in cont_val:
                                cont_val['envFrom'] = []
                            cont_val['envFrom'].extend(env_from_item)

        if 'imagePullSecrets' not in final_values:
             final_values['imagePullSecrets'] = [{"name": "dockerhub-secret"}]
        
        # Inject local database connection info
        if self._model.database and self._model.database.local:
            db_host = f"{self._model.name}-db-rw.{self._model.namespace}.svc.cluster.local"
            
            if app_name == "authentik":
                if 'authentik' not in final_values: final_values['authentik'] = {}
                if 'postgresql' not in final_values['authentik']: final_values['authentik']['postgresql'] = {}
                final_values['authentik']['postgresql'].update({
                    "host": db_host,
                    "name": self._model.name,
                    "user": self._model.name,
                    "port": 5432,
                    "existingSecret": f"{self._model.name}-db-app"
                })
                if 'postgresql' in final_values: final_values['postgresql']['enabled'] = False
                
                # Force stable names for Redis and Authentik
                if 'redis' not in final_values: final_values['redis'] = {}
                final_values['redis'].update({
                    "enabled": True,
                    "fullnameOverride": f"{self._model.name}-redis"
                })
                
                # Ensure the main secret is correctly set to -vars
                final_values['authentik']['existingSecret'] = "authentik-vars"
                final_values['fullnameOverride'] = self._model.name
                
                if 'global' not in final_values: final_values['global'] = {}
                if 'env' not in final_values['global']: final_values['global']['env'] = []
                final_values['global']['env'].extend([
                    {"name": "AUTHENTIK_POSTGRESQL__HOST", "value": db_host},
                    {"name": "AUTHENTIK_POSTGRESQL__NAME", "value": self._model.name},
                    {"name": "AUTHENTIK_POSTGRESQL__USER", "value": self._model.name},
                    {"name": "AUTHENTIK_POSTGRESQL__PORT", "value": "5432"},
                    {"name": "AUTHENTIK_POSTGRESQL__PASSWORD", "valueFrom": {"secretKeyRef": {"name": f"{self._model.name}-db-app", "key": "password"}}},
                    # Force Redis host to stable name (authentik-redis-master)
                    {"name": "AUTHENTIK_REDIS__HOST", "value": f"{self._model.name}-redis-master"},
                ])
            else:
                if 'env' not in final_values: final_values['env'] = []
                final_values['env'].extend([
                    {"name": "DATABASE_URL", "value": f"postgresql://{self._model.name}:{self._model.name}@{db_host}:5432/{self._model.name}"},
                    {"name": "DB_HOST", "value": db_host},
                    {"name": "DB_PORT", "value": "5432"},
                    {"name": "DB_NAME", "value": self._model.name},
                    {"name": "DB_USER", "value": self._model.name},
                    {"name": "DB_PASSWORD", "valueFrom": {"secretKeyRef": {"name": f"{self._model.name}-db-app", "key": "password"}}},
                ])

        # Generic fullnameOverride for all apps to improve predictability
        if 'fullnameOverride' not in final_values:
            final_values['fullnameOverride'] = self._model.name

        release = helm.Release(
            self._model.name,
            helm.ReleaseArgs(
                name=self._model.name, # Force deterministic release name (Pulumi may still add suffix)
                chart=chart_name,
                version=chart_version,
                repository_opts=helm.RepositoryOptsArgs(repo=repo_url),
                values=final_values,
                namespace=self._model.namespace,
                timeout=600,
            ),
            opts=opts,
        )
        
        return {"release": release}

def create_generic_app(model: AppModel) -> GenericHelmApp:
    return GenericHelmApp(model)
