import yaml
import subprocess
import os
import pytest
from pathlib import Path

def get_apps_config():
    with open("apps.yaml", "r") as f:
        return yaml.safe_load(f)

def test_pvc_security_context():
    """
    Validates that any application declaring `storage` in apps.yaml
    generates manifests where Pods mounting PVCs explicitly set `fsGroup` 
    or `runAsUser`/`runAsNonRoot` to prevent Permission Denied errors 
    on persistent storage (like the Vaultwarden issue).
    """
    config = get_apps_config()
    apps = config.get("apps", [])
    
    errors = []
    
    for app_config in apps:
        app_name = app_config.get("name")
        storage_configs = app_config.get("storage", [])
        
        # Only strictly enforce securityContext if the app has persistent storage configured
        if not storage_configs:
            continue
            
        if "helm" not in app_config:
            continue
            
        helm_conf = app_config["helm"]
        repo = helm_conf.get("repo")
        chart = helm_conf.get("chart")
        version = helm_conf.get("version")
        values = helm_conf.get("values", {})
        
        repo_name = f"repo-{app_name}"
        is_oci = repo.startswith("oci://")

        if not is_oci:
            subprocess.run(["helm", "repo", "add", repo_name, repo, "--force-update"], capture_output=True)
            chart_ref = f"{repo_name}/{chart}"
        else:
            chart_ref = f"{repo}/{chart}"
        
        values_file = f"/tmp/values-{app_name}.yaml"
        with open(values_file, "w") as f:
            yaml.dump(values, f)
            
        res = subprocess.run(
            ["helm", "template", app_name, chart_ref, "--version", str(version), "-n", app_config.get("namespace", "default"), "-f", values_file],
            capture_output=True,
            text=True
        )
        
        try:
            os.remove(values_file)
        except OSError:
            pass

        if res.returncode != 0:
            errors.append(f"{app_name} failed helm template: {res.stderr.strip()}")
            continue

        # Parse manifests 
        for doc in yaml.safe_load_all(res.stdout):
            if not doc or not isinstance(doc, dict):
                continue
            kind = doc.get("kind")
            if kind not in ["Deployment", "StatefulSet", "DaemonSet"]:
                continue
                
            try:
                spec = doc.get("spec", {})
                template_spec = spec.get("template", {}).get("spec", {})
                volumes = template_spec.get("volumes") or []
                
                # Check if this workload mounts a PVC
                has_pvc = any("persistentVolumeClaim" in v for v in volumes if isinstance(v, dict))
                
                if has_pvc:
                    # Look for pod-level security context
                    pod_sc = template_spec.get("securityContext", {})
                    has_fsgroup = "fsGroup" in pod_sc or "runAsUser" in pod_sc
                    
                    # Look for container-level security context
                    containers = template_spec.get("containers", [])
                    has_container_sc = any("securityContext" in c and ("runAsUser" in c["securityContext"] or "runAsNonRoot" in c["securityContext"]) for c in containers)
                    
                    if not (has_fsgroup or has_container_sc):
                        name = doc.get("metadata", {}).get("name", "unknown")
                        errors.append(f"App '{app_name}' ({kind}/{name}) mounts persistent storage but lacks a safe SecurityContext (missing fsGroup, runAsUser, or runAsNonRoot). Add to helm.values.podSecurityContext or helm.values.securityContext.")
            except KeyError:
                pass
                
    if errors:
        error_msg = "\\n".join(errors)
        pytest.fail(f"Security Context validation failed:\\n{error_msg}")

if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
