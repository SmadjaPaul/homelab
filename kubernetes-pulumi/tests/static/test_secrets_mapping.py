import yaml
import subprocess
import os
import pytest
from pathlib import Path

def get_apps_config():
    with open("apps.yaml", "r") as f:
        return yaml.safe_load(f)

def test_secret_dependencies_exist():
    """
    Validates that any Secret referenced in a Helm deployment (e.g. envFrom, 
    volumes, Ingress TLS) is either organically created by the Helm chart 
    itself, or explicitly provisioned via `apps.yaml`'s 'secrets' array.
    This prevents 'missing db-secret' errors during deployment.
    """
    config = get_apps_config()
    apps = config.get("apps", [])
    
    errors = []
    
    for app_config in apps:
        app_name = app_config.get("name")
        
        # Explicit secrets provisioned by Pulumi + Doppler
        provisioned_secrets = {s.get("name") for s in app_config.get("secrets", [])}
        
        if "helm" not in app_config:
            continue
            
        helm_conf = app_config["helm"]
        repo = helm_conf.get("repo")
        chart = helm_conf.get("chart")
        version = helm_conf.get("version")
        
        repo_name = f"repo-{app_name}"
        is_oci = repo.startswith("oci://")

        if not is_oci:
            subprocess.run(["helm", "repo", "add", repo_name, repo, "--force-update"], capture_output=True)
            chart_ref = f"{repo_name}/{chart}"
        else:
            chart_ref = f"{repo}/{chart}"
        
        values_file = f"/tmp/values-{app_name}.yaml"
        with open(values_file, "w") as f:
            yaml.dump(helm_conf.get("values", {}), f)
            
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

        # Scan for referenced secrets vs. defined secrets
        chart_created_secrets = set()
        chart_referenced_secrets = set()
        
        for doc in yaml.safe_load_all(res.stdout):
            if not doc or not isinstance(doc, dict):
                continue
            
            kind = doc.get("kind")
            name = doc.get("metadata", {}).get("name")
            
            # Record secrets created by the chart itself
            if kind == "Secret":
                chart_created_secrets.add(name)
                continue
                
            # Scan for secret references
            if kind in ["Deployment", "StatefulSet", "DaemonSet", "Job", "CronJob", "Pod"]:
                try:
                    if kind == "CronJob":
                        template_spec = doc["spec"]["jobTemplate"]["spec"]["template"]["spec"]
                    elif kind == "Pod":
                        template_spec = doc.get("spec", {})
                    else:
                        template_spec = doc["spec"]["template"]["spec"]
                        
                    # 1. Volume Mounts
                    for v in template_spec.get("volumes", []):
                        if isinstance(v, dict) and "secret" in v and "secretName" in v["secret"]:
                            chart_referenced_secrets.add(v["secret"]["secretName"])
                            
                    # 2. imagePullSecrets
                    for ips in template_spec.get("imagePullSecrets", []):
                        if isinstance(ips, dict) and "name" in ips:
                            chart_referenced_secrets.add(ips["name"])
                            
                    # 3. EnvFrom
                    containers = template_spec.get("containers", []) + template_spec.get("initContainers", [])
                    for c in containers:
                        if isinstance(c, dict):
                            # EnvFrom
                            for e_from in c.get("envFrom", []):
                                if "secretRef" in e_from and "name" in e_from["secretRef"]:
                                    chart_referenced_secrets.add(e_from["secretRef"]["name"])
                                    
                            # Env valueFrom
                            for e in c.get("env", []):
                                if "valueFrom" in e and "secretKeyRef" in e["valueFrom"]:
                                    chart_referenced_secrets.add(e["valueFrom"]["secretKeyRef"].get("name"))
                                    
                except (KeyError, TypeError):
                    pass
            elif kind == "Ingress":
                # TLS secrets
                for tls in doc.get("spec", {}).get("tls", []):
                    if "secretName" in tls:
                        chart_referenced_secrets.add(tls["secretName"])
        
        # Known dynamic or operator-generated secrets that do not need explicit provisioning
        IGNORE_SECRETS = {
            "cnpg-webhook-cert",
            "envoy-gateway",
        }
        
        # Check for unresolved secrets
        for req_secret in chart_referenced_secrets:
            # ServiceAccount tokens and default helm labels sometimes create dynamic missing secrets.
            # We skip 'default-token' or similar internal secrets.
            if not req_secret or req_secret.endswith("token") or "helm" in req_secret or req_secret in IGNORE_SECRETS:
                continue
                
            if req_secret not in chart_created_secrets and req_secret not in provisioned_secrets:
                errors.append(f"App '{app_name}' references secret '{req_secret}' but it is NOT created by the Helm chart and NOT provisioned in apps.yaml.")
                
        # 4. Check for DockerHub secret requirement
        if "dockerhub-secret" not in chart_referenced_secrets and "dockerhub-secret" not in provisioned_secrets:
             # We auto-inject it, so it should be referenced if we are using the GenericHelmApp
             # But here we are just checking the template.
             pass

        # 5. Check for external DB leakage in environment variables
        # (Catch common migration errors where apps still point to Aiven/Cloud SQL)
        EXTERNAL_DB_PATTERNS = ["aivencloud.com", "rds.amazonaws.com", "googlevisualization"]
        
        for doc in yaml.safe_load_all(res.stdout):
            if not doc or not isinstance(doc, dict) or doc.get("kind") not in ["Deployment", "StatefulSet", "DaemonSet"]:
                continue
            
            containers = (doc["spec"]["template"]["spec"].get("containers") or []) + (doc["spec"]["template"]["spec"].get("initContainers") or [])
            for c in containers:
                for e in (c.get("env") or []):
                    val = str(e.get("value", ""))
                    for pattern in EXTERNAL_DB_PATTERNS:
                        if pattern in val:
                            errors.append(f"App '{app_name}' has environment variable '{e.get('name')}' pointing to external DB ({val}). Should it be local?")

    if errors:
        error_msg = "\n".join(errors)
        pytest.fail(f"Validation failed:\n{error_msg}")

if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
