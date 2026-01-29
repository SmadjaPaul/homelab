# Secrets Management with SOPS

This directory contains encrypted secrets managed by [SOPS](https://github.com/getsops/sops).

## Setup

### 1. Install SOPS and age

```bash
brew install sops age
```

### 2. Get the private key

The private key is stored securely (not in this repo). To decrypt secrets:

```bash
# Copy the private key to the expected location
mkdir -p ~/.config/sops/age
# Paste the private key content into:
vim ~/.config/sops/age/keys.txt
```

### 3. Decrypt secrets

```bash
# Decrypt a file
sops -d secrets/cloudflare.enc.yaml

# Edit a file (decrypts, opens editor, re-encrypts)
sops secrets/cloudflare.enc.yaml
```

## Creating New Secrets

### Option 1: Encrypt existing file

```bash
# Create plaintext file (don't commit this!)
cat > secrets/new-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
stringData:
  password: super-secret-value
EOF

# Encrypt it
sops -e secrets/new-secret.yaml > secrets/new-secret.enc.yaml

# Delete plaintext
rm secrets/new-secret.yaml

# Commit encrypted version
git add secrets/new-secret.enc.yaml
```

### Option 2: Create encrypted file directly

```bash
sops secrets/new-secret.enc.yaml
# This opens your editor with a template
```

## File Patterns

The `.sops.yaml` config auto-detects which files to encrypt:

| Pattern | Description |
|---------|-------------|
| `kubernetes/**/secrets*.yaml` | K8s secrets (encrypts data/stringData) |
| `terraform/**/secrets.tfvars` | Terraform sensitive vars |
| `secrets/*.yaml` | Any YAML in secrets folder |
| `*.env.enc` | Encrypted env files |

## ArgoCD Integration

ArgoCD can decrypt SOPS secrets using the [argocd-vault-plugin](https://argocd-vault-plugin.readthedocs.io/) or [ksops](https://github.com/viaduct-ai/kustomize-sops).

Our setup uses **ksops** for Kustomize-based decryption.

## Security Notes

- ✅ **DO commit**: `*.enc.yaml`, `.sops.yaml`
- ❌ **NEVER commit**: `keys.txt`, unencrypted secrets, plaintext `.yaml` secrets
- 🔐 **Backup**: Store `keys.txt` in a password manager (Bitwarden)
