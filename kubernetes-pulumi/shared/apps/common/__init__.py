"""
Common Kubernetes constructs.

Note: Registry is lazily imported to avoid heavy dependencies (pulumi_hcloud)
being loaded during test collection or when not needed.
"""


def __getattr__(name):
    if name == "AppRegistry":
        from shared.apps.common.registry import AppRegistry

        return AppRegistry
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


__all__ = [
    # Registry - lazy loaded
    "AppRegistry",
]
