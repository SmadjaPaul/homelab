#!/bin/bash
# Talos Linux Installation Script
# Story: 1.1 - Install and Configure Talos Linux Base System
# This script automates the Talos Linux installation process

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CONTROL_PLANE_IP="192.168.1.100"
CLUSTER_NAME="homelab-cluster"
TALOS_VERSION="v1.12.1"
CONFIG_DIR="$(dirname "$0")"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if talosctl is installed
    if ! command -v talosctl &> /dev/null; then
        log_error "talosctl is not installed. Please install it first:"
        echo "  https://www.talos.dev/latest/talos-guides/install/talosctl/"
        exit 1
    fi

    # Check if kubectl is installed (optional but recommended)
    if ! command -v kubectl &> /dev/null; then
        log_warn "kubectl is not installed. It's recommended for cluster management."
    fi

    # Check if config files exist
    if [ ! -f "${CONFIG_DIR}/controlplane.yaml" ]; then
        log_error "controlplane.yaml not found in ${CONFIG_DIR}"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

generate_secrets() {
    log_info "Generating cluster secrets..."

    if [ ! -f "${CONFIG_DIR}/talos-secrets.yaml" ]; then
        talosctl gen secrets -o "${CONFIG_DIR}/talos-secrets.yaml"
        log_info "Cluster secrets generated: ${CONFIG_DIR}/talos-secrets.yaml"
        log_warn "⚠️  IMPORTANT: Store talos-secrets.yaml securely. Do NOT commit to Git!"
    else
        log_warn "talos-secrets.yaml already exists. Skipping generation."
    fi

    # Extract cluster secret from talos-secrets.yaml and update controlplane.yaml
    if [ -f "${CONFIG_DIR}/talos-secrets.yaml" ] && [ -f "${CONFIG_DIR}/controlplane.yaml" ]; then
        log_info "Updating controlplane.yaml with cluster secret..."
        # Extract secret from talos-secrets.yaml (format: secret: "base64encodedsecret")
        CLUSTER_SECRET=$(grep -A 5 "^cluster:" "${CONFIG_DIR}/talos-secrets.yaml" | grep "^\s*secret:" | sed 's/.*secret:\s*["'\'']\(.*\)["'\'']/\1/' | head -1)
        if [ -z "${CLUSTER_SECRET}" ]; then
            # Try alternative format (unquoted)
            CLUSTER_SECRET=$(grep -A 5 "^cluster:" "${CONFIG_DIR}/talos-secrets.yaml" | grep "^\s*secret:" | awk '{print $2}' | head -1)
        fi
        if [ -n "${CLUSTER_SECRET}" ] && [ "${CLUSTER_SECRET}" != "null" ]; then
            # Create backup
            cp "${CONFIG_DIR}/controlplane.yaml" "${CONFIG_DIR}/controlplane.yaml.bak"
            # Replace placeholder (escape special characters for sed)
            ESCAPED_SECRET=$(printf '%s\n' "${CLUSTER_SECRET}" | sed 's/[[\.*^$()+?{|]/\\&/g')
            if grep -q "<CLUSTER_SECRET>" "${CONFIG_DIR}/controlplane.yaml"; then
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    # macOS sed requires different syntax
                    sed -i '' "s/<CLUSTER_SECRET>/${ESCAPED_SECRET}/g" "${CONFIG_DIR}/controlplane.yaml"
                else
                    sed -i "s/<CLUSTER_SECRET>/${ESCAPED_SECRET}/g" "${CONFIG_DIR}/controlplane.yaml"
                fi
                log_info "Cluster secret updated in controlplane.yaml"
                log_info "Backup saved as controlplane.yaml.bak"
            else
                log_warn "No <CLUSTER_SECRET> placeholder found in controlplane.yaml. Manual update may be required."
            fi
        else
            log_warn "Could not extract cluster secret from talos-secrets.yaml"
            log_info "Alternative: Use 'talosctl gen config' to generate complete config with secrets"
        fi
    fi
}

validate_config() {
    log_info "Validating Talos configuration..."

    if talosctl validate --config "${CONFIG_DIR}/controlplane.yaml"; then
        log_info "Configuration is valid"
    else
        log_error "Configuration validation failed"
        exit 1
    fi
}

apply_config() {
    log_info "Applying Talos configuration to ${CONTROL_PLANE_IP}..."

    log_warn "This will apply the configuration to the Talos node."
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi

    talosctl apply-config \
        --insecure \
        --nodes "${CONTROL_PLANE_IP}" \
        --file "${CONFIG_DIR}/controlplane.yaml"

    log_info "Configuration applied successfully"
}

generate_kubeconfig() {
    log_info "Generating kubeconfig..."

    talosctl kubeconfig \
        --nodes "${CONTROL_PLANE_IP}" \
        --output "${CONFIG_DIR}/kubeconfig"

    log_info "kubeconfig generated: ${CONFIG_DIR}/kubeconfig"
    log_info "To use kubectl, run: export KUBECONFIG=${CONFIG_DIR}/kubeconfig"
}

verify_installation() {
    log_info "Verifying installation..."

    # Check Talos version
    log_info "Talos version:"
    talosctl version --nodes "${CONTROL_PLANE_IP}" || log_warn "Could not get version"

    # Check node status
    log_info "Node status:"
    talosctl get nodes --nodes "${CONTROL_PLANE_IP}" || log_warn "Could not get nodes"

    # Check Kubernetes cluster
    if [ -f "${CONFIG_DIR}/kubeconfig" ]; then
        export KUBECONFIG="${CONFIG_DIR}/kubeconfig"
        log_info "Kubernetes nodes:"
        kubectl get nodes || log_warn "Could not get Kubernetes nodes"
    fi

    log_info "Verification complete"
}

main() {
    log_info "Starting Talos Linux installation process"
    log_info "Cluster: ${CLUSTER_NAME}"
    log_info "Control Plane IP: ${CONTROL_PLANE_IP}"
    log_info "Talos Version: ${TALOS_VERSION}"
    echo

    check_prerequisites
    generate_secrets
    validate_config
    apply_config
    generate_kubeconfig
    verify_installation

    log_info "✨ Installation complete!"
    log_info "Next steps:"
    log_info "  1. Configure ZFS storage pool (Story 1.2)"
    log_info "  2. Deploy Flux GitOps (Story 1.3)"
    log_info "  3. Configure firewall rules (Story 2.1)"
}

# Run main function
main "$@"
