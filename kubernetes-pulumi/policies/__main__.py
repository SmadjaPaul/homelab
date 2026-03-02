import pulumi
from pulumi_policy import (
    EnforcementLevel,
    PolicyPack,
    ReportViolation,
    ResourceValidationArgs,
    ResourceValidationPolicy,
)

def require_ingress_tls(args: ResourceValidationArgs, report_violation: ReportViolation):
    """
    Ensure that all Ingress resources configure TLS.
    """
    if args.resource_type == "kubernetes:networking.k8s.io/v1:Ingress":
        tls = args.props.get("spec", {}).get("tls")
        if not tls:
            report_violation("All Ingress resources must configure TLS to ensure encrypted external traffic.")

def require_managed_by_pulumi_label(args: ResourceValidationArgs, report_violation: ReportViolation):
    """
    Ensure all resources have `app.kubernetes.io/managed-by: pulumi` label unless they are explicitly Helm or Component resources.
    """
    # Skip non-Kubernetes native resources and Helm charts (which manage their own labels)
    resource_type = args.resource_type.lower()
    if not resource_type.startswith("kubernetes:") or "helm" in resource_type:
        return

    metadata = args.props.get("metadata", {})
    labels = metadata.get("labels", {})
    
    # Check if the label exists and is correct
    if labels.get("app.kubernetes.io/managed-by") != "pulumi":
        report_violation(
            "All locally managed Kubernetes resources must include the 'app.kubernetes.io/managed-by: pulumi' label for clean auditing."
        )

# Combine into a policy pack
PolicyPack(
    name="homelab-kubernetes-policies",
    enforcement_level=EnforcementLevel.ADVISORY,
    policies=[
        ResourceValidationPolicy(
            name="require-ingress-tls",
            description="Ensures all Ingress resources configure TLS.",
            validate=require_ingress_tls,
            enforcement_level=EnforcementLevel.MANDATORY,
        ),
        ResourceValidationPolicy(
            name="require-managed-by-label",
            description="Ensures all explicit k8s resources are labeled as managed by Pulumi.",
            validate=require_managed_by_pulumi_label,
            enforcement_level=EnforcementLevel.ADVISORY,
        ),
    ],
)
