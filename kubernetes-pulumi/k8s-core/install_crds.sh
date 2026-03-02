#!/bin/bash
echo "Installing CRDs directly via kubectl server-side apply..."
kubectl apply --server-side -f k8s-core/crds/
