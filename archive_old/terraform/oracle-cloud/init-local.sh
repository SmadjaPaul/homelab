#!/usr/bin/env bash
# Local Terraform init for OCI backend — injects tenancy namespace into backend.tf
# Usage: ./init-local.sh [namespace]
#   If namespace omitted: uses OCI_OBJECT_STORAGE_NAMESPACE env or prompts.
#   After first apply: terraform output -json | jq -r '.tfstate_bucket.value.namespace'
set -e
cd "$(dirname "$0")"
NAMESPACE="${1:-$OCI_OBJECT_STORAGE_NAMESPACE}"
if [ -z "$NAMESPACE" ]; then
  echo "Usage: $0 <namespace>   # or set OCI_OBJECT_STORAGE_NAMESPACE"
  echo "Get namespace: terraform output -json | jq -r '.tfstate_bucket.value.namespace'"
  exit 1
fi
sed -i.bak "s/YOUR_TENANCY_NAMESPACE/$NAMESPACE/g" backend.tf
terraform init -reconfigure
echo "Backend configured with namespace=$NAMESPACE. Run terraform plan/apply as needed."
