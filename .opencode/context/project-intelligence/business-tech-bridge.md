<!-- Context: project-intelligence/bridge | Priority: medium | Version: 1.0 | Updated: 2026-02-19 -->

# Business ↔ Tech Bridge

> Document how business needs translate to technical solutions.

## Core Mapping

| Business Need | Technical Solution | Why This Mapping | Business Value |
|---------------|-------------------|------------------|----------------|
| Self-hosting services | OCI + Kubernetes | Cost-effective infrastructure | Save money |
| Automated deployments | Flux GitOps | No manual interventions | Save time |
| Secure secret management | Doppler | Centralized secrets | Security |
| Reproducible infra | Terraform + GitOps | Version controlled | Reliability |

## Key Trade-offs

| Situation | Decision Made | Rationale |
|-----------|---------------|------------|
| ArgoCD vs Flux | Flux | Lighter weight |
| KCL vs Kustomize | Kustomize | Simpler tooling |
| Vault vs Doppler | Doppler | Easier setup |
