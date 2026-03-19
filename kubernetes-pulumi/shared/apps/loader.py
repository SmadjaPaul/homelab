"""
App loader — loads and parses apps.yaml configuration.

Provides:
- Loading apps.yaml with Pydantic validation into `AppModel` objects
- Filtering apps by cluster (`load_for_cluster`)
- Topological sort for dependency ordering (`get_deployment_order`)

RELATED FILES:
  - apps.yaml: The file this loader reads (source of truth for all apps)
  - shared/utils/schemas.py: `AppModel`, `S3BucketConfig` — Pydantic models
  - k8s-apps/__main__.py: Calls `AppLoader.load_for_cluster()` to get the app list
"""

from __future__ import annotations

from collections import defaultdict
from pathlib import Path
from typing import Optional

import yaml
from pydantic import ValidationError

from shared.utils.schemas import (
    AppModel,
    IdentitiesModel,
    ExposureMode,
    StorageBoxConfig,
)
from shared.apps.sso_presets import resolve_sso


class DependencyGraph:
    """Manages app dependencies and provides topological sorting."""

    def __init__(self):
        self.graph: dict[str, list[str]] = defaultdict(list)
        self.nodes: set[str] = set()

    def add_node(self, name: str) -> None:
        self.nodes.add(name)

    def add_edge(self, from_node: str, to_node: str) -> None:
        self.graph[from_node].append(to_node)
        self.nodes.add(from_node)
        self.nodes.add(to_node)

    def get_dependencies(self, name: str) -> list[str]:
        return self.graph.get(name, [])

    def detect_cycles(self) -> list[list[str]]:
        cycles = []
        visited = set()
        rec_stack = set()
        path = []

        def dfs(node: str) -> bool:
            visited.add(node)
            rec_stack.add(node)
            path.append(node)

            for neighbor in self.graph.get(node, []):
                if neighbor not in visited:
                    if dfs(neighbor):
                        return True
                elif neighbor in rec_stack:
                    cycle_start = path.index(neighbor)
                    cycles.append(path[cycle_start:] + [neighbor])
                    return True

            path.pop()
            rec_stack.remove(node)
            return False

        for node in self.nodes:
            if node not in visited:
                dfs(node)

        return cycles

    def topological_sort(self) -> list[str]:
        """Return nodes in deployment order (dependencies first)."""
        cycles = self.detect_cycles()
        if cycles:
            raise ValueError(f"Cyclic dependencies detected: {cycles}")

        in_degree = {node: 0 for node in self.nodes}
        for node in sorted(self.nodes):
            for dep in self.graph.get(node, []):
                in_degree[node] += 1

        queue = sorted([node for node in self.nodes if in_degree[node] == 0])
        result = []

        while queue:
            node = queue.pop(0)
            result.append(node)

            for other in sorted(self.nodes):
                if node in self.graph.get(other, []):
                    in_degree[other] -= 1
                    if in_degree[other] == 0:
                        queue.append(other)
                        queue.sort()  # Keep queue stable

        if len(result) != len(self.nodes):
            raise ValueError("Graph has a cycle")

        return result


KNOWN_NAMESPACES = {
    "kube-system",
    "default",
    "external-secrets",
    "cert-manager",
    "external-dns",
    "cloudflared",
    "homelab",
    "music",
    "vaultwarden",
    "cnpg-system",
    "kyverno",
    "envoy-gateway",
    "o11y",
    "authentik",
}


def resolve_conventions(apps: list[AppModel], domain: str):
    """Auto-derive hostnames and dependencies based on conventions."""
    for app in apps:
        # 1. Hostname auto-derivation
        if not app.network.hostname and app.network.hostname_prefix:
            app.network.hostname = f"{app.network.hostname_prefix}.{domain}"

        # 2. Implicit dependencies
        implicit = set()
        if app.secrets:
            implicit.add("external-secrets")

        if app.network.hostname and app.network.mode in (
            ExposureMode.PUBLIC,
            ExposureMode.PROTECTED,
        ):
            implicit.add("cloudflared")
            implicit.add("kube-system")

        if app.persistence.database and app.persistence.database.local:
            implicit.add("cnpg-system")

        if "postgres" in app.requires:
            if not app.persistence.database:
                from shared.utils.schemas import DatabaseConfig

                app.persistence.database = DatabaseConfig(local=True)
            else:
                app.persistence.database.local = True
            implicit.add("cnpg-system")

        if "redis" in app.requires:
            implicit.add("redis")

        if "s3" in app.requires:
            # Placeholder for S3 provider abstraction
            pass

        resolve_sso(app, domain)

        if app.auth.sso or app.auth.enabled or app.auth.provisioning:
            implicit.add("authentik")

        # Merge dependencies
        app.dependencies = list(set(app.dependencies) | implicit)


class AppLoader:
    """Loads and parses apps.yaml configuration."""

    def __init__(self, config_path: Optional[str] = None):
        if config_path is None:
            project_root = Path(__file__).parent.parent.parent
            config_path = str(project_root / "apps.yaml")

        self.config_path = Path(config_path)

    def _load_yaml(self) -> dict:
        if not self.config_path.exists():
            return {}
        with open(self.config_path) as f:
            return yaml.safe_load(f) or {}

    def load(self) -> list[AppModel]:
        """Load apps from shared.apps.yaml."""
        data = self._load_yaml()
        apps_data = data.get("apps", [])
        domain = data.get("domain", "smadja.dev")

        apps = []
        for app_data in apps_data:
            try:
                app = AppModel(**app_data)
                apps.append(app)
            except ValidationError as e:
                print(f"Error validating app {app_data.get('name', 'unknown')}: {e}")

        resolve_conventions(apps, domain)

        # Preflight validation — warn on configuration issues
        from shared.utils.preflight import validate_all

        errors = validate_all(apps, domain)
        for e in errors:
            print(f"[Preflight Warning] {e}")

        return apps

    def get_full_config(self) -> dict:
        """Return the full raw configuration as a dict."""
        return self._load_yaml()

    def load_identities(self) -> Optional[IdentitiesModel]:
        """Load identities from shared.apps.yaml."""
        data = self._load_yaml()
        identities_data = data.get("identities")
        if not identities_data:
            return None

        try:
            return IdentitiesModel(**identities_data)
        except ValidationError as e:
            print(f"Error validating identities: {e}")
            return None

    def load_storagebox_config(self) -> Optional[StorageBoxConfig]:
        """Load and validate the storagebox section from apps.yaml."""
        data = self._load_yaml()
        storagebox_data = data.get("storagebox")
        if not storagebox_data:
            return None
        try:
            return StorageBoxConfig(**storagebox_data)
        except Exception as e:
            print(f"Error validating storagebox config: {e}")
            return None

    def load_for_cluster(self, cluster: str) -> list[AppModel]:
        """Load apps filtered by cluster."""
        all_apps = self.load()
        return [app for app in all_apps if cluster in app.clusters]

    def build_dependency_graph(self, apps: list[AppModel]) -> DependencyGraph:
        """Build dependency graph from shared.apps."""
        graph = DependencyGraph()
        for app in apps:
            graph.add_node(app.name)
            for dep in app.dependencies:
                graph.add_node(dep)
                graph.add_edge(app.name, dep)
        return graph

    def get_deployment_order(self, cluster: str) -> list[str]:
        """Get apps in deployment order (dependencies first)."""
        apps = self.load_for_cluster(cluster)
        graph = self.build_dependency_graph(apps)

        # Filter to only app names (not infrastructure)
        app_names = {app.name for app in apps}
        ordered = [n for n in graph.topological_sort() if n in app_names]

        return ordered

    def validate(self) -> tuple[bool, str]:
        """Validate apps.yaml."""
        try:
            apps = self.load()
            errors = []

            # Validate dependencies
            known = KNOWN_NAMESPACES.copy()
            known.update(app.name for app in apps)

            for app in apps:
                for dep in app.dependencies:
                    if dep not in known:
                        errors.append(f"App '{app.name}' depends on unknown: '{dep}'")

            # Check for cycles
            graph = self.build_dependency_graph(apps)
            cycles = graph.detect_cycles()
            if cycles:
                errors.append(f"Cyclic dependencies: {cycles}")

            return len(errors) == 0, "; ".join(errors)
        except Exception as e:
            return False, str(e)


# Convenience functions
_loader: Optional[AppLoader] = None


def get_loader(config_path: Optional[str] = None) -> AppLoader:
    global _loader
    if _loader is None:
        _loader = AppLoader(config_path)
    return _loader


def load_apps(cluster: str) -> list[AppModel]:
    """Load apps for a cluster."""
    return get_loader().load_for_cluster(cluster)


def load_identities() -> Optional[IdentitiesModel]:
    """Load identities configuration."""
    return get_loader().load_identities()


def get_deployment_order(cluster: str) -> list[str]:
    """Get deployment order for a cluster."""
    return get_loader().get_deployment_order(cluster)


def validate_apps() -> tuple[bool, str]:
    """Validate apps.yaml."""
    return get_loader().validate()
