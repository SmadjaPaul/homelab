# Secrets Management (Doppler)

This document describes the secrets management strategy for the Homelab V1.0.

## Architecture

We use **Doppler** comprehensively across the stack.

```
┌─────────────┐   Pulumi Sync  ┌──────────────┐     ┌─────────────────┐
│             │───────────────►│ Kubernetes   │     │                 │
│   Doppler   │                │ External     │────►│ K8s Secrets     │
│  (Central)  │◄───────────────│ Secrets      │     │                 │
│             │    Fail-Fast   │ Operator     │     │                 │
└─────────────┘   Pre-flight   └──────────────┘     └─────────────────┘
```

## How It Works

1. **Pre-flight Validation (Fail-Fast)**:
   When `pulumi preview` or `pulumi up` runs locally, the registry queries Doppler to fetch a full map of keys. It checks this map against every `SecretRequirement` defined in `apps.yaml`.
   If a key is missing, Pulumi fails execution **immediately** before touching the cluster.

2. **External Secrets Delivery**:
   Pulumi generates corresponding `ExternalSecret` custom resources.
   The `External Secrets Operator` running in the cluster subsequently syncs those keys from Doppler directly into classic Kubernetes `Secret` objects.
   The Pods consume these Kubernetes secrets natively.

## Setup

Ensure you have Doppler installed and logged in on your machine where `pulumi` runs:

```bash
brew install doppler
doppler login
```

Because Pulumi (via `pulumiverse-doppler`) uses your local CLI authentication, there is no need to manually place tokens in GitHub or local env files once authenticated via CLI for stack development.

## Adding New Secrets

1. Add the secret to your Doppler Project (e.g. `homelab`, config `prd`):
   ```bash
   doppler secrets set MY_NEW_APP_API_KEY="supersecret" -p homelab -c prd
   ```

2. Reference it in `kubernetes-pulumi/apps.yaml` for your application:
   ```yaml
   secrets:
     - name: my-app-creds
       keys:
         API_KEY: MY_NEW_APP_API_KEY   # K8s key : Doppler Key
   ```

3. Re-deploy via Pulumi:
   ```bash
   cd kubernetes-pulumi/k8s-apps
   pulumi up
   ```

## Security Best Practices

1. **No Hardcoding**: Never commit secrets to git or to `apps.yaml`.
2. **Rotation**: Rotate secrets in Doppler; the External Secrets Operator will periodically sync and update the `Secret` in Kubernetes. (You may need to restart the application Pods to pick up the changes).
3. **Least Privilege**: Only map exactly the Doppler keys the specific app requires. Do not map all secrets to all namespaces.
