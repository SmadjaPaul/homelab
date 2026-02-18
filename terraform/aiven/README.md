# Aiven Terraform Configuration

This module manages Aiven services for the homelab using Terraform.

## Prerequisites

1. Install Terraform >= 1.0
2. Get your Aiven API token from [Aiven Console](https://console.aiven.io/)

## Usage

### Initialize Terraform

```bash
cd terraform/aiven
terraform init
```

### Create Services

Create a `terraform.tfvars` file with your configuration:

```hcl
aiven_token    = "your-aiven-api-token"
project_name   = "your-aiven-project-name"
cloud_name     = "google-europe-west1"

# Enable services you want to create
create_dragonfly = true
create_kafka     = false
create_redis     = false
```

### Plan and Apply

```bash
# Preview changes
terraform plan -var-file=terraform.tfvars

# Apply changes
terraform apply -var-file=terraform.tfvars
```

## Available Services

### Dragonfly
- **Purpose**: In-memory database for caching and message queues
- **Plan**: startup-4 (development)
- **Features**: Redis-compatible API, persistence

### Kafka
- **Purpose**: Event streaming and message queue
- **Plan**: startup-2 (development)
- **Features**: Kafka Connect, Schema Registry

### Redis
- **Purpose**: Caching layer
- **Plan**: startup-4 (development)
- **Features**: Persistence, eviction policies

## Integration with Kubernetes

The Terraform configuration creates Aiven service credentials as Kubernetes secrets. These can be used with External Secrets Operator:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: my-service-secrets
spec:
  secretStoreRef:
    name: doppler
    kind: ClusterSecretStore
  refreshInterval: 1h
  target:
    name: my-service-connection
  dataFrom:
    - extract:
        key: my-service-credentials
```

## Security

- All sensitive values are marked as `sensitive = true`
- Termination protection is enabled by default
- Use remote state storage for production deployments
- Store API tokens in a secure location (not in version control)

## Costs

Aiven offers a free tier for development. Check [Aiven pricing](https://aiven.io/pricing) for details.
