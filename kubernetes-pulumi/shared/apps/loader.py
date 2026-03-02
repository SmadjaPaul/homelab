"""
App loader - loads and parses apps.yaml configuration.

This module provides:
- Loading apps.yaml configuration with Pydantic validation
- Filtering apps by cluster
- Topological sort for dependency ordering
"""

from __future__ import annotations

from collections import defaultdict
from pathlib import Path
from typing import Any, Optional

import yaml
from pydantic import ValidationError

from shared.utils.schemas import AppModel, IdentitiesModel


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
        for node in self.nodes:
            for dep in self.graph.get(node, []):
                in_degree[node] += 1

        queue = [node for node in self.nodes if in_degree[node] == 0]
        result = []

        while queue:
            node = queue.pop(0)
            result.append(node)

            for other in self.nodes:
                if node in self.graph.get(other, []):
                    in_degree[other] -= 1
                    if in_degree[other] == 0:
                        queue.append(other)

        if len(result) != len(self.nodes):
            raise ValueError("Graph has a cycle")

        return result


KNOWN_NAMESPACES = {
    "kube-system", "default", "external-secrets", "cert-manager",
    "external-dns", "cloudflared", "homelab",
    "music", "vaultwarden", "cnpg-system", "kyverno",
    "envoy-gateway", "o11y", "authentik",
}


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

        apps = []
        for app_data in apps_data:
            try:
                app = AppModel(**app_data)
                apps.append(app)
            except ValidationError as e:
                print(f"Error validating app {app_data.get('name', 'unknown')}: {e}")

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
                        errors.append(
                            f"App '{app.name}' depends on unknown: '{dep}'"
                        )

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
